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
  sku_name                    = "standard"

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
