#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type    = string
  default = "rg-aks-test-01"
}

variable "location" {
  type    = string
  default = "westeurope"
}



variable "vnet" {
  description = "Feature of vnet"
  type = object({ address_space = list(string), name = string })
  default = {
    address_space = ["10.0.0.0/8"]
    name = "aks-vnet-01"
  }
}

variable "subnet_node" {
  description = "Feature of subnet of node"
  type = object({ address_prefixes = list(string), name = string })
  default = {
    address_prefixes = ["10.240.0.0/16"]
    name = "node-subnet-01"
  }
}

variable "aks" {
  description = "Feature of aks"
  type = object({
    name       = string
    version    = string
    dns_prefix = string
    default_node_pool = object({
      name = optional(string, "default")
      node_count = optional(number, 3)
      vm_size = optional(string, "Standard_DS2_v2")
    })
  })
  default = {
    name       = "aks-test-01"
    version    = "1.33.0"
    dns_prefix = "aks-dns-test-01"
    default_node_pool = {
      name       = "default"
      node_count = 3
      vm_size    = "Standard_DS2_v2"
    }
  }
}

variable "cilium" {
  description = "Feature of cilium"
  type = object({
    version = optional(string, "1.14.3")
    kube-proxy-replacement = optional(bool, false)
    ebpf-hostrouting = optional(bool, false)
    hubble = optional(bool, false)
    hubble-ui = optional(bool, false)
    gateway-api = optional(bool, false)
    preflight-version = optional(string, null)
    upgrade-compatibility = optional(string, null)
  })
  default = {
    version                = "1.15.1"
    kube-proxy-replacement = false
    ebpf-hostrouting       = false
    hubble                 = false
    hubble-ui              = false
    gateway-api            = false
  }
}


variable "tags" {
  description = "A map of tags to assign to the resources."
  type = map(string)
  default = {
    Environment = "Test"
    Project     = "AKS-Deployment"
    ManagedBy   = "Terraform"
  }
}


variable "app1_public_ip_name" {
  description = "Name of the public IP for app1"
  type        = string
  default     = "app1-public-ip"
}

variable "dns-rg_name" {
  description = "Resource group name for app1 public IP"
  type        = string
  default     = "rg-dns-test-01"
}