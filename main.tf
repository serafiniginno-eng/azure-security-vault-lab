# Configuración del proveedor y recursos principales de seguridad
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
      # Protección contra borrado accidental
      purge_soft_delete_on_destroy = true
    }
  }
}

# Obtener configuración del cliente actual
data "azurerm_client_config" "current" {}

# 1. Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = "rg-security-lab-prod"
  location = var.location
}

# 2. Azure Key Vault (Blindado con Network ACLs)
resource "azurerm_key_vault" "vault" {
  name                        = var.vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization   = true

  # Bloque de seguridad de red: Denegar acceso por defecto
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# 3. Storage Account (Blindado con TLS 1.2 y Reglas de Red)
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Configuraciones críticas de Ciberseguridad
  enable_https_traffic_only     = true
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false

  # Reglas de red para el almacenamiento
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# ---------------------------------------------------------
# PROYECTO: OBSERVABILIDAD Y RESPUESTA ANTE INCIDENTES
# ---------------------------------------------------------

# 1. Workspace de Log Analytics: El centro de comando para los registros
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-security-monitoring-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 2. Configuración de Diagnóstico: Conecta el Key Vault con el centro de comando
resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-keyvault-security"
  target_resource_id         = azurerm_key_vault.vault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AuditEvent" # Esto registra CUALQUIER intento de ver tus secretos
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# 3. Alerta de Seguridad KQL: Se activa si alguien recibe un "Acceso Denegado"
resource "azurerm_monitor_scheduled_query_rules_alert" "unauthorized_access_alert" {
  name                = "alert-unauthorized-vault-access"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  data_source_id = azurerm_log_analytics_workspace.law.id
  description    = "Alerta de Ciberseguridad: Intento de acceso no autorizado detectado."
  enabled        = true
  
  # Consulta en lenguaje KQL (Kusto Query Language)
  query          = <<-QUERY
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where ResultSignature == "Forbidden"
    | summarize Count = count() by bin(TimeGenerated, 5m), Resource
    | where Count > 0
  QUERY
  
  severity    = 1 # Nivel de urgencia: Alta
  frequency   = 5
  window_size = 5

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}

# Definición de la Identidad Gestionada por el Usuario
resource "azurerm_user_assigned_identity" "app_id" {
  name                = "id-web-app-prod-001" # Nomenclatura estándar
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    ManagedBy   = "Terraform"
    Project     = "SecurityLab"
    Environment = "Production"
  }
}
# 1. El Puente: Asignación de Rol (Principio de Mínimo Privilegio)
# Estándar: Azure WAF - Seguridad de Identidad
resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Secrets User" # Solo lectura de secretos
  principal_id         = azurerm_user_assigned_identity.app_id.principal_id
}

# 2. El Contenido: Secreto con cumplimiento de directivas (CIS 8.1)
resource "azurerm_key_vault_secret" "db_password" {
  name            = "db-password-prod"
  value           = "M0v3r_T3rr4f0rm_S3cur3!" # Valor sensible cifrado
  key_vault_id    = azurerm_key_vault.vault.id
  expiration_date = "2026-12-31T23:59:59Z" # Fecha de expiración obligatoria

  tags = {
    DataClassification = "Confidential"
  }
}

# 1. Creación de la Red Virtual (VNET)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-security-lab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 2. Subnet dedicada para Private Endpoints
# Es una buena práctica separar los endpoints de las máquinas virtuales o apps
resource "azurerm_subnet" "pe_subnet" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  # Bloqueo de políticas de red para Private Endpoints (Requerido por Azure)
  private_endpoint_network_policies_enabled = true
}
# 3. Zona DNS Privada para Key Vault
resource "azurerm_private_dns_zone" "dnsvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# 4. Vincular el DNS con tu VNET
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "dns-link-vnet"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsvault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_key_vault" "vault" {
  name                        = var.vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.kv_sku
  enable_rbac_authorization   = true

  # --- CONFIGURACIÓN DE BLINDAJE (NIST/CIS) ---
  
  # Desactiva el acceso desde internet completamente
  public_network_access_enabled = false 

  # Protección contra Ransomware: permite recuperar el Vault si es borrado
  soft_delete_retention_days = 90
  
  # Impide que los secretos se eliminen permanentemente antes de los 90 días
  purge_protection_enabled   = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-${var.vault_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id # Referencia a la subred del Paso 1

  private_service_connection {
    name                           = "psc-keyvault-connection"
    private_connection_resource_id = azurerm_key_vault.vault.id
    is_manual_connection           = false
    subresource_names              = ["vault"] # Indica que nos conectamos al servicio de secretos
  }

  private_dns_zone_group {
    name                 = "dns-group-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsvault.id] # Referencia al Paso 2
  }
}

