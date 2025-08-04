terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Reverted to previous successful version
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    cilium = {
      source = "littlejo/cilium"
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
