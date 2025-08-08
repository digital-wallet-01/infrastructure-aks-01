
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
#
# # #############################################################################
# # # 1. Create the static Public IP for AKS Load Balancer
# # #############################################################################
# resource "azurerm_public_ip" "aks_static_ip" {
#   name                = "aks-lb-ip"
#   location            = azurerm_resource_group.rg_terraform_aks.location
#   resource_group_name = azurerm_resource_group.rg_terraform_aks.name
#   allocation_method   = "Static"
#   sku                 = "Standard" # Required for AKS
#   tags                = var.tags
# }
