# --- Outputs for GitHub Secrets and consumption by other modules ---
output "azure_client_id" {
  description = "The Client ID of the Azure AD Application. Use as AZURE_CLIENT_ID in GitHub Secrets."
  value       = azuread_application.github_aks_deployer_app.client_id
}

output "azure_tenant_id" {
  description = "The Tenant ID of your Azure subscription. Use as AZURE_TENANT_ID in GitHub Secrets."
  value       = data.azurerm_client_config.current.tenant_id
}