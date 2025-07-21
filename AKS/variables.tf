#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type    = string
  default = "rg-aks-testing-01"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "vnet_address_prefix" {
  description = "The address prefix for the Virtual Hub."
  type = list(string)
  default = ["10.1.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "The address prefix for the Virtual Hub."
  type = list(string)
  default = ["10.1.1.0/24"]
}


variable "vnet_name" {
  type        = string
  default     = "vnet1"
  description = "The name of the virtual network."
}

variable "subnet_name" {
  type        = string
  default     = "subnet1"
  description = "The name of the subnet."
}
