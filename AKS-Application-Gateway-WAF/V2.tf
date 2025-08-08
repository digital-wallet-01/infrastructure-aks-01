#
#
#
# ##################################################################################
# # APPLICATION GATEWAY WAF
# ##################################################################################
#
# # Application Gateway with WAF enabled
# resource "azurerm_application_gateway" "appgw" {
#   name                = "appgw-waf"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
#
#   sku {
#     name     = "WAF_v2"
#     tier     = "WAF_v2"
#     capacity = 2
#   }
#
#   gateway_ip_configuration {
#     name      = "gateway-ip-config"
#     subnet_id = azurerm_subnet.appgw_subnet.id
#   }
#
#   frontend_ip_configuration {
#     name                 = "appgw-fe"
#     public_ip_address_id = azurerm_public_ip.appgw_pip.id
#   }
#
#   frontend_port {
#     name = "http"
#     port = 80
#   }
#
#   backend_address_pool {
#     name = "default-pool"
#   }
#
#   backend_http_settings {
#     name                  = "default-setting"
#     cookie_based_affinity = "Disabled"
#     port                  = 80
#     protocol              = "Http"
#     request_timeout       = 30
#   }
#
#   http_listener {
#     name                           = "listener"
#     frontend_ip_configuration_name = "appgw-fe"
#     frontend_port_name             = "http"
#     protocol                       = "Http"
#   }
#
#   request_routing_rule {
#     name                       = "rule1"
#     rule_type                  = "Basic"
#     http_listener_name         = "listener"
#     backend_address_pool_name  = "default-pool"
#     backend_http_settings_name = "default-setting"
#     priority                   = 100
#   }
#
#   waf_configuration {
#     enabled          = true
#     firewall_mode    = "Prevention"
#     rule_set_type    = "OWASP"
#     rule_set_version = "3.2"
#   }
#
#   depends_on = [
#     azurerm_subnet.appgw_subnet,
#     azurerm_public_ip.appgw_pip
#   ]
# }
#
#
# # Subnet for Application Gateway
# resource "azurerm_subnet" "appgw_subnet" {
#   name                 = "appgw-subnet"
#   resource_group_name  = azurerm_resource_group.rg_terraform_aks.name
#   virtual_network_name = azurerm_virtual_network.aks-vnet.name
#   address_prefixes = ["10.250.0.0/24"] # Ensure this is a non-overlapping range within your VNet
#   # Delegation removed as we are reverting to traditional App Gateway
# }
#
#
#
# # Public IP for the Application Gateway
# resource "azurerm_public_ip" "appgw_pip" {
#   name                = "appgw-pip"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }
#
#
# # User-assigned identity for AGIC
# resource "azurerm_user_assigned_identity" "agic_identity" {
#   name                = "agic-identity"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
# }
#
#
#
# # Role assignment for AGIC to control the App Gateway
# resource "azurerm_role_assignment" "agic_appgw_contributor" {
#   scope                = azurerm_application_gateway.appgw.id
#   role_definition_name = "Contributor"
#   principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
# }
#
# # Role assignment for AGIC to have Reader access on the Resource Group
# resource "azurerm_role_assignment" "agic_rg_reader" {
#   scope                = azurerm_resource_group.rg_terraform_aks.id
#   role_definition_name = "Reader"
#   principal_id         = azurerm_user_assigned_identity.agic_identity.principal_id
# }
#
#
# # Grant AGIC identity 'Get' permission on Key Vault secrets
# resource "azurerm_key_vault_access_policy" "agic_kv_access" {
#   key_vault_id = azurerm_key_vault.cert_vault.id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = azurerm_user_assigned_identity.agic_identity.principal_id
#
#   secret_permissions = [
#     "Get",
#   ]
#   certificate_permissions = [
#     "Get",
#   ]
# }
#
#
#
#
# ##################################################################################
# # Cert manager and Key Vault Sync
# ##################################################################################
#
#
# # Azure Key Vault for storing certificates
# resource "azurerm_key_vault" "cert_vault" {
#   name = "certvault${random_string.suffix.result}" # Must be globally unique
#   location                   = var.location
#   resource_group_name        = azurerm_resource_group.rg_terraform_aks.name
#   tenant_id                  = data.azurerm_client_config.current.tenant_id
#   sku_name                   = "standard"
#   soft_delete_retention_days = 7
#   purge_protection_enabled   = false # Set to true for production for data recovery
# }
#
# #User-assigned identity for cert-manager DNS challenges
# resource "azurerm_user_assigned_identity" "cert_manager_dns_identity" {
#   name                = "cert-manager-dns-identity"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
# }
#
# # Azure DNS Zone for Let's Encrypt DNS01 challenge
# resource "azurerm_dns_zone" "main_dns_zone" {
#   name                = var.domain_name
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
# }
#
#
#
# # User-assigned identity for cert-manager-key-vault-sync
# resource "azurerm_user_assigned_identity" "cert_manager_kv_sync_identity" {
#   name                = "cert-manager-kv-sync-identity"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
# }
#
#
#
#
# # Grant cert-manager-key-vault-sync identity 'Set' permission on Key Vault secrets
# resource "azurerm_key_vault_access_policy" "cert_manager_kv_sync_access" {
#   key_vault_id = azurerm_key_vault.cert_vault.id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = azurerm_user_assigned_identity.cert_manager_kv_sync_identity.principal_id
#
#   secret_permissions = [
#     "Set",
#   ]
#   certificate_permissions = [
#     "Import",
#   ]
# }
#
# # Grant cert-manager identity 'Contributor' role on the DNS zone for DNS01 challenge
# resource "azurerm_role_assignment" "cert_manager_dns_contributor" {
#   scope                = azurerm_dns_zone.main_dns_zone.id
#   role_definition_name = "DNS Zone Contributor"
#   principal_id         = azurerm_user_assigned_identity.cert_manager_dns_identity.principal_id
#
#   depends_on = [
#     azurerm_kubernetes_cluster.aks-cluster,
#     azurerm_user_assigned_identity.cert_manager_dns_identity
#   ]
# }
#
#
#
# # cert-manager Helm chart
# resource "helm_release" "cert_manager" {
#   name             = "cert-manager"
#   repository       = "https://charts.jetstack.io"
#   chart            = "cert-manager"
#   version          = "v1.14.5"
#   namespace        = "cert-manager"
#   create_namespace = true
#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
#   depends_on = [
#     azurerm_kubernetes_cluster.aks-cluster # Removed local_file.current dependency
#   ]
# }



# ##################################################################################
# # VARIABLES
# ##################################################################################
#
#
# variable "domain_name" {
#   description = "The root domain name for your application (e.g., example.com)."
#   type        = string
#   default = "ztsikkerhed.dk"
# }
#
# variable "domain_name_san_friendly_name" {
#   description = "A friendly name for the Key Vault secret, typically derived from the domain, e.g., 'yourdomain-com-cert'."
#   type        = string
#   default = "zt-cert"
# }
#
# variable "letsencrypt_email" {
#   description = "Email address for Let's Encrypt notifications."
#   type        = string
#   default = "fadidasus@gmail.com"
# }



# ##################################################################################
# # PROVIDERS
# ##################################################################################
#

# #  Helm provider configuration for Kubernetes ()
# provider "helm" {
#   kubernetes {
#     host = azurerm_kubernetes_cluster.aks-cluster.kube_config.0.host
#     client_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_certificate)
#     client_key = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_key)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.cluster_ca_certificate)
#   }
# }
#
#
#
#
# #  Kubernetes provider configuration
# provider "kubernetes" {
#   host = azurerm_kubernetes_cluster.aks-cluster.kube_config.0.host
#   client_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_certificate)
#   client_key = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.client_key)
#   cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks-cluster.kube_config.0.cluster_ca_certificate)
# }
