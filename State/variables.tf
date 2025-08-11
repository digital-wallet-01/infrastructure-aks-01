#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type    = string
  default = "rg-terraform-state-01"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "naming_prefix" {
  type    = string
  default = "terraformstate"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    Environment = "Test"
    Project     = "AKS-Deployment"
    ManagedBy   = "Terraform"
  }
}

variable "account_replication_type" {
  type        = string
  default     = "LRS"
  description = "The replication type for the storage account."
}

variable "account_tier" {
  type        = string
  default     = "Standard"
  description = "The performance tier for the storage account."
}


variable "aks_state_container_name" {
  description = "Name of the blob container for AKS Terraform state."
  type        = string
  default     = "aks-tfstate" # Customize this container name
}

variable "dns_state_container_name" {
  description = "Name of the blob container for AKS Terraform state."
  type        = string
  default     = "dns-tfstate" # Customize this container name
}


variable "container_access_type" {
  description = "Access type for the storage container."
  type        = string
  default     = "private"
}

variable "storage_account_https_only" {
  description = "Enforce HTTPS only traffic for the storage account."
  type        = bool
  default     = true
}
variable "storage_account_tier" {
  description = "The tier of the storage account (e.g., Standard, Premium)."
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "The replication type of the storage account (e.g., LRS, GRS, ZRS)."
  type        = string
  default     = "LRS"
}

variable "blob_soft_delete_retention_days" {
  description = "Number of days to retain deleted blobs for soft delete."
  type        = number
  default     = 7
}
