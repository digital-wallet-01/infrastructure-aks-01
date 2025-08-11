
# Create an Azure Resource Group to hold the DNS Zone
resource "azurerm_resource_group" "dns_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create a resource lock on the resource group to prevent accidental deletion
resource "azurerm_management_lock" "rg_lock" {
  name                = "prevent-deletion-lock"
  scope               = azurerm_resource_group.dns_rg.id
  lock_level          = "CanNotDelete"
  notes               = "This lock prevents accidental deletion of the resource group and its contents."
}

# Create the Azure DNS Zone for the domain
resource "azurerm_dns_zone" "dns_zone" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.dns_rg.name
}

# Create a static public IP address for app1
resource "azurerm_public_ip" "app1_ip" {
  name                = var.app1_ip_address-name
  resource_group_name = azurerm_resource_group.dns_rg.name
  location            = azurerm_resource_group.dns_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a static public IP address for app2
resource "azurerm_public_ip" "app2_ip" {
  name                = var.app2_ip_address-name
  resource_group_name = azurerm_resource_group.dns_rg.name
  location            = azurerm_resource_group.dns_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create an A record for the app1 subdomain
resource "azurerm_dns_a_record" "app1_a_record" {
  name                = "app1"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.dns_rg.name
  ttl                 = 3600
  records             = [azurerm_public_ip.app1_ip.ip_address]
}

# Create an A record for the app2 subdomain
resource "azurerm_dns_a_record" "app2_a_record" {
  name                = "app2"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.dns_rg.name
  ttl                 = 3600
  records             = [azurerm_public_ip.app2_ip.ip_address]
}

# Create a local file to store the Azure nameservers
resource "local_file" "azure_nameservers_file" {
  filename        = "azure_nameservers.txt"
  content         = join("\n", azurerm_dns_zone.dns_zone.name_servers)
  file_permission = "0644"
}