
##################################################################################
# OUTPUTS
##################################################################################

output "storage_account_name" {
  value = azurerm_storage_account.terraform_state_storage.name
  description = "Name of the Azure Storage Account for Terraform state."
}

output "storage_container_name_aks" {
  value = azurerm_storage_container.terraform_aks_state_container.name
  description = "Name of the Azure Storage Container for AKS Terraform state."
}


output "storage_container_name_dns" {
  value = azurerm_storage_container.terraform_dns_state_container.name
  description = "Name of the Azure Storage Container for DNS Terraform state."
}


output "resource_group_name" {
  value = azurerm_resource_group.rg_terraform_state.name
  description = "Name of the Resource Group containing the Terraform state storage."
}
