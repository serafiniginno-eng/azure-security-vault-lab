variable "location" {
  type    = string
  default = "East US"
}

variable "vault_name" {
  type    = string
  default = "kv-secure-lab-001" 
}

variable "storage_name" {
  type    = string
  default = "stsecdatalab001" # Solo minúsculas y números
}
