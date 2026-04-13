variable "location" {
  description = "The Azure Region where all resources in this example should be created."
  default     = "East US"
}

variable "vault_name" {
  description = "The name of the Key Vault."
  default     = "kv-security-lab-001"
}

variable "storage_name" {
  description = "The name of the Storage Account."
  default     = "stsecuritylab001"
}

variable "kv_sku" {
  description = "El SKU del Key Vault (standard o premium)."
  type        = string
  default     = "standard"
}
terraform init
terraform plan
terraform apply
