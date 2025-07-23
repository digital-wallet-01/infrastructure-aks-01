# Resource Group for the cluster
resource "azurerm_resource_group" "rg_terraform_aks" {
  location = var.location
  name     = var.resource_group_name
  tags     = var.tags
}
# Generate a random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

##################################################################################
# NETWORK RESOURCES
##################################################################################

# Virtual Network and Subnet for AKS
resource "azurerm_virtual_network" "aks-vnet" {
  address_space       = var.vnet.address_space
  name                = var.vnet.name
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
  location            = var.location
}

# Subnet for AKS nodes
resource "azurerm_subnet" "node-subnet" {
  address_prefixes     = var.subnet_node.address_prefixes
  name                 = var.subnet_node.name
  virtual_network_name = azurerm_virtual_network.aks-vnet.name
  resource_group_name  = azurerm_resource_group.rg_terraform_aks.name
}


##################################################################################
# KUBERNETES CLUSTER RESOURCES
##################################################################################
# AKS Cluster with BYO CNI
resource "azurerm_kubernetes_cluster" "aks-cluster" {
  name                 = var.aks.name
  kubernetes_version   = var.aks.version
  azure_policy_enabled = true
  dns_prefix           = var.aks.dns_prefix
  # private_cluster_enabled = true
  # private_dns_zone_id     = "System"

  default_node_pool {
    name           = var.aks.default_node_pool.name
    node_count     = var.aks.default_node_pool.node_count
    vm_size        = var.aks.default_node_pool.vm_size
    vnet_subnet_id = azurerm_subnet.node-subnet.id
  }

  network_profile {
    network_plugin    = "none"
    network_policy    = null
    load_balancer_sku = "standard"

  }

  identity {
    type = "SystemAssigned"
  }

  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name


}

# Container Registry for storing images
resource "azurerm_container_registry" "acr" {
  name = "acrtest01${random_string.suffix.result}" # Globally unique name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
  sku                 = "Standard"
  admin_enabled       = false
  tags                = var.tags
}


##################################################################################
# IDENTITY RESOURCES
##################################################################################
# 2. Grant AKS managed identity permission to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks-cluster.identity[0].principal_id
}

##################################################################################
# CONFIGURATION
##################################################################################
# 3. Output the kubeconfig file for AKS
resource "local_file" "current" {
  content  = azurerm_kubernetes_cluster.aks-cluster.kube_config_raw
  filename = "${path.module}/kubeconfig"
}

# Cilium configuration for AKS
resource "cilium" "config" {
  set = [
    "aksbyocni.enabled=true",
    "nodeinit.enabled=true",
    "azure.resourceGroup=${azurerm_resource_group.rg_terraform_aks.name}",
  ]
  version = var.cilium.version
  depends_on = [local_file.current]
}

resource "cilium_hubble" "hubble" {
  ui = true
}