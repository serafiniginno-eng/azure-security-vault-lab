# 1. Nombre del Grupo de Recursos creado
output "resource_group_name" {
  description = "El nombre del grupo de recursos donde se crearon los activos."
  value       = azurerm_resource_group.rg.name
}

# 2. URI del Key Vault (Dirección para conectar aplicaciones)
output "key_vault_uri" {
  description = "La URL de la bóveda para que las aplicaciones lean secretos."
  value       = azurerm_key_vault.vault.vault_uri
}

# 3. ID del Storage Account (Identificador único)
output "storage_account_id" {
  description = "El ID único del almacenamiento seguro."
  value       = azurerm_storage_account.storage.id
}
