# Configure the Azure AD provider
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0" # Use a compatible version
    }
    # We no longer need the azurerm provider in this specific config
    # as we're not creating Azure RGs or role assignments here.
    # We keep it for data source if current tenant_id needs fetching via azurerm.
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {} # This block is mandatory for azurerm provider v3.x and later
}


# Data source to get the current client configuration (tenant ID)
data "azurerm_client_config" "current" {}


# 1. Create an Azure AD Application Registration
resource "azuread_application" "github_aks_deployer_app" {
  display_name   = var.app_display_name
  sign_in_audience = "AzureADMyOrg"
}

# 2. Create a Service Principal for the Application
resource "azuread_service_principal" "github_aks_deployer_sp" {
  client_id = azuread_application.github_aks_deployer_app.client_id
  app_role_assignment_required = false
}

# 3. Create a Federated Identity Credential
resource "azuread_application_federated_identity_credential" "github_oidc_credential" {
  application_id = azuread_application.github_aks_deployer_app.client_id # Use client_id here

  display_name          = "github-aks-deploy-cred-${var.github_repo_name}"
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${var.github_org}/${var.github_repo_name}:${var.github_branch_ref}"
  audiences             = ["api://AzureADTokenExchange"]
}

