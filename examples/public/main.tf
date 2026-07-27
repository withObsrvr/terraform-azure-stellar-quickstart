# Public demo deployment: the container gets a public IP and FQDN with NO
# network isolation. Every service — Friendbot included — is reachable by
# anyone on the internet. Use for short-lived demos only; destroy promptly.

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

  location       = "eastus"
  environment    = "demo"
  network_access = "public"

  stellar_network = "local"

  # Must be unique within the region:
  # dns_name_label = "my-stellar-demo"
}

output "stellar_endpoint" {
  description = "Public endpoint for the quickstart services"
  value       = module.stellar_quickstart.stellar_endpoint
}

output "container_group_public_ip" {
  description = "Public IP of the container group"
  value       = module.stellar_quickstart.container_group_public_ip
}
