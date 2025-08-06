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

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg_terraform_aks.name
  virtual_network_name = azurerm_virtual_network.aks-vnet.name
  address_prefixes = ["10.250.0.0/24"] # Ensure this is a non-overlapping range within your VNet
  # Delegation removed as we are reverting to traditional App Gateway
}

# Public IP for the Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
  allocation_method   = "Static"
  sku                 = "Standard"
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
    network_plugin    = "none"
    network_policy    = null
    load_balancer_sku = "standard"
    pod_cidr          = "10.1.0.0/16"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
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

  ingress_application_gateway {
    gateway_id  = azurerm_application_gateway.appgw.id
  }

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
# IDENTITY RESOURCES AND PERMISSIONS
##################################################################################

# User-assigned identity for AGIC
resource "azurerm_user_assigned_identity" "agic_identity" {
  name                = "agic-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# User-assigned identity for cert-manager-key-vault-sync
resource "azurerm_user_assigned_identity" "cert_manager_kv_sync_identity" {
  name                = "cert-manager-kv-sync-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# Role assignment for AGIC to control the App Gateway
resource "azurerm_role_assignment" "agic_appgw_contributor" {
  scope                = azurerm_resource_group.rg_terraform_aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
}

# Grant AKS managed identity permission to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks-cluster.identity[0].principal_id
  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster # Ensure cluster is created before assigning role # consider testing without it
  ]
}

# Azure Key Vault for storing certificates
resource "azurerm_key_vault" "cert_vault" {
  name = "certvault${random_string.suffix.result}" # Must be globally unique
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg_terraform_aks.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to true for production for data recovery
}

# Grant AGIC identity 'Get' permission on Key Vault secrets
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

# Grant cert-manager-key-vault-sync identity 'Set' permission on Key Vault secrets
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

# Azure DNS Zone for Let's Encrypt DNS01 challenge
resource "azurerm_dns_zone" "main_dns_zone" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.rg_terraform_aks.name
}

# Grant cert-manager identity 'Contributor' role on the DNS zone for DNS01 challenge
resource "azurerm_role_assignment" "cert_manager_dns_contributor" {
  scope                = azurerm_dns_zone.main_dns_zone.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster # Ensure cluster is created first
  ]
}


##################################################################################
# APPLICATION GATEWAY WAF
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


##################################################################################
# CONFIGURATION
##################################################################################
# 3. Output the kubeconfig file for AKS ()
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
    "ipam.mode=cluster-pool",
    "ipam.operator.clusterPoolIPv4PodCIDRList={10.1.0.0/16}",
    "ipam.operator.clusterPoolIPv4MaskSize=24",
    "tls.enabled=true",
    # Enable automatic certificate generation for internal Cilium communication
    "hubble.tls.enabled=true",
    "hubble.tls.auto.enabled=true",
    "hubble.tls.auto.method=helm"
  ]
  version = var.cilium.version
  depends_on = [local_file.current]
}

#Data source for current Azure client configuration
data "azurerm_client_config" "current" {}


# cert-manager Helm chart 
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.5"
  namespace        = "cert-manager"
  create_namespace = true
  set {
    name  = "installCRDs"
    value = "true"
  }
  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster,
    local_file.current
  ]
}
