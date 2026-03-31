# 1. Configuración del Proveedor (Azure Resource Manager)
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
      # Protección contra borrado accidental (Purge Protection)
      purge_soft_delete_on_destroy = true
    }
  }
}

# 2. Grupo de Recursos (El contenedor lógico de tu lab)
resource "azurerm_resource_group" "rg" {
  name     = "rg-security-lab-prod"
  location = var.location # Usa la variable que ya definiste en variables.tf
}

# 3. Azure Key Vault (Tu bóveda de seguridad)
resource "azurerm_key_vault" "vault" {
  name                = var.vault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = "00000000-0000-0000-0000-000000000000" # ID de ejemplo para portafolio
  sku_name            = "standard"

  # Configuración de Red: Bloqueo de acceso público (Zero Trust)
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# 4. Storage Account (Almacenamiento Cifrado)
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  
  # Prevención de fugas: Deshabilitar acceso desde Internet público
  public_network_access_enabled = false
}
