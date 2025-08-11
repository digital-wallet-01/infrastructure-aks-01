
variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
  default     = "rg-dns-test-01"
}

variable "location" {
  description = "The Azure region where the resources will be created."
  type        = string
  default     = "West Europe"
}

variable "domain_name" {
  description = "Your domain name (e.g., example.com)."
  type        = string
  default     = "ztsikkerhed.dk"

}

variable "app1_ip_address-name" {
  description = "The public IP address to link to your domain."
  type        = string
  default = "app1-public-ip"
}

variable "app2_ip_address-name" {
  description = "The public IP address to link to your domain."
  type        = string
  default = "app2-public-ip"
}