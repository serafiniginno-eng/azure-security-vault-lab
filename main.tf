# --- 1. CONFIGURACIÓN INICIAL ---
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-security-lab-prod"
  location = var.location
}

# --- 2. INFRAESTRUCTURA DE RED (PRIVATE LINK) ---
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-security-lab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "pe_subnet" {
  name                                      = "snet-private-endpoints"
  resource_group_name                       = azurerm_resource_group.rg.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  address_prefixes                          = ["10.0.1.0/24"]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_private_dns_zone" "dnsvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "dns-link-vnet"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsvault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# --- 3. CORE DE SEGURIDAD: KEY VAULT BLINDADO ---
resource "azurerm_key_vault" "vault" {
  name                        = var.vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.kv_sku
  enabled_for_disk_encryption = true
  enable_rbac_authorization   = true

  # HARDENING CONTRA RANSOMWARE Y EXPOSICIÓN
  public_network_access_enabled = false  # Zero Trust: Puerta a internet cerrada
  soft_delete_retention_days    = 90     # Capacidad de recuperación
  purge_protection_enabled      = true   # Inmutabilidad de borrado

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-${var.vault_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                           = "psc-keyvault-connection"
    private_connection_resource_id = azurerm_key_vault.vault.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "dns-group-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsvault.id]
  }
}

# --- 4. IDENTIDAD Y CONTENIDO ---
resource "azurerm_user_assigned_identity" "app_id" {
  name                = "id-web-app-prod-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_id.principal_id
}

resource "azurerm_key_vault_secret" "db_password" {
  name            = "db-password-prod"
  value           = "M0v3r_T3rr4f0rm_S3cur3!"
  key_vault_id    = azurerm_key_vault.vault.id
  expiration_date = "2026-12-31T23:59:59Z"
}

# --- 5. OBSERVABILIDAD ---
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-security-monitoring-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-keyvault-security"
  target_resource_id         = azurerm_key_vault.vault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log { category = "AuditEvent" }
  metric      { category = "AllMetrics" }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "unauthorized_access_alert" {
  name                = "alert-unauthorized-vault-access"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  data_source_id      = azurerm_log_analytics_workspace.law.id
  enabled             = true
  query               = <<-QUERY
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where ResultSignature == "Forbidden"
    | summarize Count = count() by bin(TimeGenerated, 5m), Resource
    | where Count > 0
  QUERY
  severity    = 1
  frequency   = 5
  window_size = 5
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}

# 1. Activar Microsoft Sentinel sobre el Log Analytics Workspace existente
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel_onboarding" {
  workspace_id = azurerm_log_analytics_workspace.law.id
}
# 2. Conector para Azure Activity (Detecta cambios en la infraestructura)
resource "azurerm_sentinel_data_connector_azure_activity" "azure_activity" {
  name                       = "connector-azure-activity"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel_onboarding]
}

# 3. Conector para Azure Active Directory (Detecta inicios de sesión sospechosos)
resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  name                       = "connector-aad"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel_onboarding]
}
# 4. Regla de Analítica: Detección de Fuerza Bruta en Key Vault
resource "azurerm_sentinel_log_analytics_rule_scheduled" "kv_brute_force" {
  name                       = "rule-kv-brute-force-detection"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  display_name               = "Posible Fuerza Bruta en Key Vault (MITRE T1110)"
  severity                   = "High"
  query                      = <<-KQL
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where ResultSignature == "Forbidden"
    | summarize AnomalyCount = count() by bin(TimeGenerated, 1h), CallerIPAddress, Resource
    | where AnomalyCount > 5
  KQL

  # Mapeo de Entidades para investigación (Clave para un SOC)
  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier = "Address"
      column_name = "CallerIPAddress"
    }
  }

  tactics  = ["CredentialAccess"]
  techniques = ["T1110"] # Brute Force
}
# 5. Regla de Automatización para Triaging
resource "azurerm_sentinel_automation_rule" "auto_triage" {
  name                       = "rule-auto-triage-critical"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  display_name               = "Auto-Triage: Incidentes de Key Vault"
  order                      = 1
  
  action_incident {
    order                  = 1
    status                 = "Active"
    classification         = "TruePositive"
    severity               = "High"
  }

  condition {
    operator = "Contains"
    property = "IncidentTitle"
    values   = ["Key Vault"]
  }
}
