# Full deployment: existing resource group, P2S VPN gateway for laptop
# access, testnet-sized container.

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

  resource_group_name = "rg-obsrvr-shared-dev" # pre-existing group
  environment         = "dev"

  enable_vpn_gateway = true

  stellar_network  = "testnet"
  container_cpu    = 4
  container_memory = 16
}

output "stellar_endpoint" {
  description = "Internal endpoint for the quickstart services"
  value       = module.stellar_quickstart.stellar_endpoint
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN endpoint"
  value       = module.stellar_quickstart.vpn_gateway_public_ip
}
