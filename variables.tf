variable "resource_group_name" {
  description = "Name of an existing resource group to deploy into. When null, the module creates one named rg-{project_name}-{environment}."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region. Required when the module creates the resource group; defaults to the existing resource group's location otherwise."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name used in resource naming and tags"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "stellar-quickstart"
}

variable "network_access" {
  description = "\"private\" (default) deploys the container into a VNet with a private IP only. \"public\" gives it a public IP and azurecontainer.io FQDN with no network isolation — every service, Friendbot included, becomes internet-reachable. Public is intended for short-lived demos only."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.network_access)
    error_message = "network_access must be \"private\" or \"public\"."
  }
}

variable "dns_name_label" {
  description = "DNS label for the public FQDN ({label}.{region}.azurecontainer.io); must be unique within the region. Only used when network_access = \"public\". Defaults to {project_name}-{environment}."
  type        = string
  default     = null
}

variable "enable_vpn_gateway" {
  description = "Whether to deploy a Point-to-Site VPN gateway (Entra ID auth) for access from outside the VNet. Adds ~30-45 min to provisioning and ~$140/month."
  type        = bool
  default     = false
}

variable "vnet_cidr" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "aci_subnet_cidr" {
  description = "Address prefix for the ACI subnet (delegated to container groups)"
  type        = string
  default     = "10.10.1.0/24"
}

variable "gateway_subnet_cidr" {
  description = "Address prefix for the GatewaySubnet (only used when enable_vpn_gateway = true); /27 or larger recommended"
  type        = string
  default     = "10.10.255.0/27"
}

variable "vpn_client_address_pool" {
  description = "Address pool assigned to P2S VPN clients; must not overlap the VNet CIDR. Only used when enable_vpn_gateway = true."
  type        = string
  default     = "172.16.201.0/24"
}

variable "vpn_gateway_sku" {
  description = "VPN gateway SKU. Azure retired the non-AZ SKUs (VpnGw1-5) in 2026 — only AZ SKUs can be created. Only used when enable_vpn_gateway = true."
  type        = string
  default     = "VpnGw1AZ"

  validation {
    condition     = contains(["VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.vpn_gateway_sku)
    error_message = "vpn_gateway_sku must be one of: VpnGw1AZ, VpnGw2AZ, VpnGw3AZ, VpnGw4AZ, VpnGw5AZ (Azure no longer allows creating non-AZ VPN gateway SKUs)."
  }
}

variable "vpn_gateway_public_ip_zones" {
  description = "Availability zones for the VPN gateway's public IP. AZ gateway SKUs require a zonal public IP; the default is zone-redundant across 1-3. Reduce for regions with fewer zones. Only used when enable_vpn_gateway = true."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "vpn_aad_audience" {
  description = "Application ID the P2S VPN accepts tokens for. Default is the Microsoft-registered Azure VPN Client enterprise app, which requires one-time admin consent in the tenant."
  type        = string
  default     = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
}

variable "additional_allowed_cidrs" {
  description = "Extra CIDR ranges allowed to reach port 8000 (e.g. peered VNets or hub networks). The VNet itself is always allowed."
  type        = list(string)
  default     = []
}

variable "stellar_network" {
  description = "Stellar network flag passed to the quickstart image (local = ephemeral private network)"
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "testnet", "futurenet"], var.stellar_network)
    error_message = "stellar_network must be one of: local, testnet, futurenet."
  }
}

variable "quickstart_image" {
  description = "Stellar quickstart container image to run"
  type        = string
  default     = "stellar/quickstart:latest"
}

variable "container_cpu" {
  description = "vCPUs for the container group (use 4 for testnet/futurenet)"
  type        = number
  default     = 2
}

variable "container_memory" {
  description = "Memory in GB for the container group (use 16 for testnet/futurenet)"
  type        = number
  default     = 8
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name for internal resolution"
  type        = string
  default     = "stellar.internal"
}

variable "dns_record_name" {
  description = "A record name for the quickstart endpoint inside the private DNS zone"
  type        = string
  default     = "quickstart"
}

variable "tags" {
  description = "Additional tags merged onto all resources (override defaults by using the same keys)"
  type        = map(string)
  default     = {}
}
