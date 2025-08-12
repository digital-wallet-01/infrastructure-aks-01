
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