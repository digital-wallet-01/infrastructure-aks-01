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
  type        = map(string)
  description = "A map of tags to assign to the resources."
  default = {
    environment = "SG-testing"
    owner       = "fad@conscia.com"
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
  type        = string
  default     = "terraform-aks-state-container"
  description = "The name of the container for the aks Terraform state."
}
