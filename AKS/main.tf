# Existing Resource Group for the cluster (unchanged)
resource "azurerm_resource_group" "rg_terraform_aks" {
  location = var.location
  name     = var.resource_group_name
  tags     = var.tags
}

# Generate a random suffix for globally unique names (unchanged)
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

# Subnet for Application Gateway (ADDED/FIXED)
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg_terraform_aks.name
  virtual_network_name = azurerm_virtual_network.aks-vnet.name
  address_prefixes     = ["10.250.0.0/24"] # Ensure this is a non-overlapping range
}

# Public IP for the Application Gateway (unchanged)
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

##################################################################################
# KUBERNETES CLUSTER RESOURCES (unchanged, except for AGIC identity permissions)
##################################################################################
# AKS Cluster with BYO CNI
resource "azurerm_kubernetes_cluster" "aks-cluster" {
  name                 = var.aks.name
  kubernetes_version   = var.aks.version
  azure_policy_enabled = true
  dns_prefix           = var.aks.dns_prefix
  # private_cluster_enabled = true # Consider enabling for production
  # private_dns_zone_id     = "System" # Required for private cluster

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

  # AGIC identity is already defined below, linking it here
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agic_identity.id]
  }

  # AGIC integration
  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.appgw.id
  }

  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# Container Registry for storing images (unchanged)
resource "azurerm_container_registry" "acr" {
  name                = "acrtest01${random_string.suffix.result}" # Globally unique name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
  sku                 = "Standard"
  admin_enabled       = false
  tags                = var.tags
}

##################################################################################
# IDENTITY RESOURCES AND PERMISSIONS
##################################################################################

# User-assigned identity for AGIC (unchanged)
resource "azurerm_user_assigned_identity" "agic_identity" {
  name                = "agic-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# NEW: User-assigned identity for cert-manager-key-vault-sync
resource "azurerm_user_assigned_identity" "cert_manager_kv_sync_identity" {
  name                = "cert-manager-kv-sync-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# Role assignment for AGIC to control the App Gateway (unchanged)
resource "azurerm_role_assignment" "agic_appgw_contributor" {
  scope                = azurerm_resource_group.rg_terraform_aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
}

# Grant AKS managed identity permission to pull images from ACR (unchanged)
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
}

# NEW: Azure Key Vault for storing certificates
resource "azurerm_key_vault" "cert_vault" {
  name                        = "certvault${random_string.suffix.result}" # Must be globally unique
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg_terraform_aks.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # Set to true for production for data recovery
}

# NEW: Grant AGIC identity 'Get' permission on Key Vault secrets
resource "azurerm_key_vault_access_policy" "agic_kv_access" {
  key_vault_id = azurerm_key_vault.cert_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.agic_identity.principal_id

  secret_permissions = [
    "Get", # AGIC needs to Get the certificate secret
  ]
  certificate_permissions = [
    "Get", # If you store it as a certificate object in KV
  ]
}

# NEW: Grant cert-manager-key-vault-sync identity 'Set' permission on Key Vault secrets
resource "azurerm_key_vault_access_policy" "cert_manager_kv_sync_access" {
  key_vault_id = azurerm_key_vault.cert_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.cert_manager_kv_sync_identity.principal_id

  secret_permissions = [
    "Set", # cert-manager-key-vault-sync needs to Set the certificate secret
  ]
  certificate_permissions = [
    "Import", # If you prefer to sync as certificate objects
  ]
}

# NEW: Azure DNS Zone for Let's Encrypt DNS01 challenge
resource "azurerm_dns_zone" "main_dns_zone" {
  name                = var.domain_name # e.g., "example.com"
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# NEW: Grant cert-manager identity 'Contributor' role on the DNS zone for DNS01 challenge
# Note: In a real-world scenario, you might create a more granular custom role
# for DNS zone management for cert-manager.
resource "azurerm_role_assignment" "cert_manager_dns_contributor" {
  scope                = azurerm_dns_zone.main_dns_zone.id
  role_definition_name = "Contributor" # Or a more specific custom role for DNS management
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id # Corrected reference
  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster # Ensure cluster is created first
  ]
}


##################################################################################
# APPLICATION GATEWAY WAF (unchanged for this step)
##################################################################################

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
    subnet_id = azurerm_subnet.appgw_subnet.id # Referencing the now-present appgw_subnet
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


##################################################################################
# CONFIGURATION
##################################################################################
# 3. Output the kubeconfig file for AKS (unchanged)
resource "local_file" "current" {
  content  = azurerm_kubernetes_cluster.aks-cluster.kube_config_raw
  filename = "${path.module}/kubeconfig"
}

# Cilium configuration for AKS (unchanged)
resource "cilium" "config" {
  set = [
    "aksbyocni.enabled=true",
    "nodeinit.enabled=true",
    "azure.resourceGroup=${azurerm_resource_group.rg_terraform_aks.name}",
  ]
  version = var.cilium.version
  depends_on = [local_file.current]
}

# NEW: Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

# NEW: Helm provider configuration for Kubernetes (will be used in later steps)
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks-cluster.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.cluster_ca_certificate)
  }
}

# NEW: Kubernetes provider configuration (will be used in later steps)
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks-cluster.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.cluster_ca_certificate)
}

# IMPORTANT: You'll need to define 'your-app-service' Kubernetes Service and Deployment
# in your cluster for the Ingress to route traffic to. This example assumes they exist.
