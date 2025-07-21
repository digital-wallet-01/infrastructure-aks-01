##################################################################################
# OUTPUT
##################################################################################

output "storage_account_name" {
  value = azurerm_storage_account.terraform-state-storage.name
}

output "resource_group_name" {
  value = azurerm_resource_group.rg-terraform-state-01.name
}
