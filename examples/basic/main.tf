# Minimal deployment: module creates the resource group, no VPN gateway.
# Access is from inside the VNet only (or peered VNets).

terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "stellar_quickstart" {
  source = "../.."

  location        = "eastus"
  environment     = "dev"
  stellar_network = "local"
}

output "stellar_endpoint" {
  description = "Internal endpoint for the quickstart services"
  value       = module.stellar_quickstart.stellar_endpoint
}

output "container_group_private_ip" {
  description = "Private IP of the container group"
  value       = module.stellar_quickstart.container_group_private_ip
}
