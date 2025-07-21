#############################################################################
# TERRAFORM CONFIG
#############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
  }
}

##################################################################################
# PROVIDERS
##################################################################################

provider "azurerm" {
  features {}
}


##################################################################################
# RESOURCES
##################################################################################
resource "random_integer" "strg-name" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "rg-terraform-state-01" {
  location = var.location
  name     = var.resource_group_name
  tags     = var.tags

}

resource "azurerm_storage_account" "terraform-state-storage" {
  account_replication_type = var.account_replication_type
  account_tier             = var.account_tier
  location                 = var.location
  name                     = "${var.naming_prefix}${random_integer.strg-name.result}"
  resource_group_name      = azurerm_resource_group.rg-terraform-state-01.name
  tags                     = var.tags

}

##################################################################################
# CONTAINER FOR AKS RESOURCES STATE
##################################################################################
resource "azurerm_storage_container" "terraform-aks-state" {
  name = var.aks_state_container_name

  storage_account_name = azurerm_storage_account.terraform-state-storage.name
}


##################################################################################
# SAS TOKEN FOR AKS STATE CONTAINER
##################################################################################
data "azurerm_storage_account_sas" "aks_state" {
  connection_string = azurerm_storage_account.terraform-state-storage.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start = timestamp()
  expiry = timeadd(timestamp(), "17520h")

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = false
    process = false
  }
}

##################################################################################
# LOCAL FILE TO OUTPUT SAS TOKENS
##################################################################################
resource "local_file" "post-config-ajs" {
  depends_on = [azurerm_storage_container.terraform-aks-state]

  filename = "${path.module}/aks-backend-config.txt"
  content  = <<EOF
storage_account_name = "${azurerm_storage_account.terraform-state-storage.name}"
container_name = "terraform-aks-state"
key = "aks.tfstate"
sas_token = "${data.azurerm_storage_account_sas.aks_state.sas}"
EOF
}

