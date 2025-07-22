terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Check the registry for the latest stable version and update accordingly
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
    cilium = {
      source  = "littlejo/cilium"
      version = ">=0.1.10"
    }
  }
  required_version = ">= 1.3"

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-01"
    storage_account_name = "tfstatejgyxb"
    container_name       = "aks-tfstate"
    key                  = "aks-test.tfstate"
  }
}

provider "azurerm" {
  features {}
}


provider "cilium" {
  config_path = local_file.current.filename
}
