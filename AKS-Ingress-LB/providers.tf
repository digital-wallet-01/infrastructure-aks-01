terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Reverted to previous successful version
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    cilium = {
      source  = "littlejo/cilium"
      version = "0.3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
  }
  required_version = ">= 1.8.0"
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-01"
    storage_account_name = "tfstatet5fkr"
    container_name       = "aks-tfstate"
    key                  = "aks-test.tfstate"
  }
}

provider "kubernetes" {
  alias       = "aks"
  config_path = local_file.current.filename
}

provider "azurerm" {
  features {}
}

provider "cilium" {
  config_path = local_file.current.filename
}

data "azurerm_public_ip" "app1_ip" {
  name                = var.app1_public_ip_name
  resource_group_name = var.dns-rg_name
}