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
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agic_identity.id]
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.appgw.id
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
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
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




##################################################################################
# APPLICATION GATEWAY WAF
##################################################################################

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg_terraform_aks.name
  virtual_network_name = azurerm_virtual_network.aks-vnet.name
  address_prefixes     = ["10.250.0.0/24"]
}

# Public IP for the Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# User-assigned identity for AGIC
resource "azurerm_user_assigned_identity" "agic_identity" {
  name                = "agic-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# Role assignment for AGIC to control the App Gateway
resource "azurerm_role_assignment" "agic_appgw_contributor" {
  scope                = azurerm_resource_group.rg_terraform_aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
}

# Application Gateway with WAF enabled
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-waf"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-fe"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  backend_address_pool {
    name = "default-pool"
  }

  backend_http_settings {
    name                  = "default-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "appgw-fe"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "listener"
    backend_address_pool_name  = "default-pool"
    backend_http_settings_name = "default-setting"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  depends_on = [
    azurerm_subnet.appgw_subnet,
    azurerm_public_ip.appgw_pip
  ]
}



#private cluster a
# managment vm
