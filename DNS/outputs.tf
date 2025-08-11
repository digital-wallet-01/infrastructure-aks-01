
output "azure_nameservers" {
  description = "The list of Azure Nameservers to configure in your GoDaddy account."
  value       = azurerm_dns_zone.dns_zone.name_servers
}
