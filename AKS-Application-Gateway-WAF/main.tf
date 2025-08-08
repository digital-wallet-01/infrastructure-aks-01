# Resource Group for the cluster
resource "azurerm_resource_group" "rg_terraform_aks" {
  location = var.location
  name     = var.resource_group_name
  tags     = var.tags
}

# Generate a random suffix for globally unique names ()
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

##################################################################################
# KUBERNETES CLUSTER RESOURCES with BYO CNI
##################################################################################
resource "azurerm_kubernetes_cluster" "aks-cluster" {
  name                 = var.aks.name
  kubernetes_version   = var.aks.version
  azure_policy_enabled = true
  dns_prefix           = var.aks.dns_prefix
  # private_cluster_enabled = true
  # private_dns_zone_id     = "System"

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = "10.1.0.0/16"
  }

  default_node_pool {
    name           = "systempool"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.node-subnet.id
    max_pods = 60

    # Enable autoscaling for the default node pool as well
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
  }

  identity {
    type = "SystemAssigned"
  }

  # ingress_application_gateway {
  #   gateway_id = azurerm_application_gateway.appgw.id
  # }

  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name

}
# --------------------------------------------------------------------------------
# User Node Pool
# --------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "user_node_pool" {
  name                  = "usernp"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks-cluster.id
  vm_size               = var.aks.default_node_pool.vm_size
  node_count            = var.aks.default_node_pool.node_count
  vnet_subnet_id        = azurerm_subnet.node-subnet.id
  mode                  = "User"
  max_pods              = 100

  enable_auto_scaling = true
  min_count           = 2
  max_count           = 10

  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster
  ]
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
# AKS CONFIGURATION
##################################################################################
# 3. Output the kubeconfig file for AKS ()
resource "local_file" "current" {
  content  = azurerm_kubernetes_cluster.aks-cluster.kube_config_raw
  filename = "${path.module}/kubeconfig"
}
#
# # Cilium configuration for AKS
# resource "cilium" "config" {
#   set = [
#     "aksbyocni.enabled=true",
#     "nodeinit.enabled=true",
#     "azure.resourceGroup=${azurerm_resource_group.rg_terraform_aks.name}",
#     "ipam.mode=cluster-pool",
#     "ipam.operator.clusterPoolIPv4PodCIDRList={10.1.0.0/16}",
#     "ipam.operator.clusterPoolIPv4MaskSize=24",
#     "tls.enabled=true",
#     # Enable automatic certificate generation for internal Cilium communication
#     "hubble.tls.enabled=true",
#     "hubble.tls.auto.enabled=true",
#     "hubble.tls.auto.method=helm"
#   ]
#   version = var.cilium.version
#   depends_on = [
#     local_file.current,
#     azurerm_kubernetes_cluster.aks-cluster
#   ]
# }

#Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

