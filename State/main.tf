#############################################################################
# TERRAFORM CONFIG
#############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Use a modern version for azurerm provider
    }
  }
}

##################################################################################
# PROVIDERS
##################################################################################

provider "azurerm" {
  features {}
}

##################################################################################
# RESOURCES
##################################################################################

# Generate a random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# Resource Group for Terraform State
resource "azurerm_resource_group" "rg_terraform_state" {
  location = var.location
  name     = var.resource_group_name
  tags     = var.tags
}

# Storage Account for Terraform State
resource "azurerm_storage_account" "terraform_state_storage" {
  name = "tfstate${random_string.suffix.result}" # Globally unique name
  resource_group_name      = azurerm_resource_group.rg_terraform_state.name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  tags                     = var.tags
  blob_properties {
    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
  }
  https_traffic_only_enabled = var.storage_account_https_only
}

# Container for AKS Resources State
resource "azurerm_storage_container" "terraform_aks_state_container" {
  name                  = var.aks_state_container_name
  storage_account_name  = azurerm_storage_account.terraform_state_storage.name
  container_access_type = var.container_access_type
}
