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
    storage_account_name = "tfstatejqkms"
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

#  Helm provider configuration for Kubernetes ()
provider "helm" {
  kubernetes {
    host = azurerm_kubernetes_cluster.aks-cluster.kube_config.0.host
    client_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_certificate)
    client_key = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.cluster_ca_certificate)
  }
}

#  Kubernetes provider configuration
provider "kubernetes" {
  host = azurerm_kubernetes_cluster.aks-cluster.kube_config.0.host
  client_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_certificate)
  client_key = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.cluster_ca_certificate)
}
