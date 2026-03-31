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
