output "resource_group_name" {
  description = "Name of the resource group containing all resources (created or supplied)"
  value       = local.resource_group_name
}

output "stellar_endpoint" {
  description = "Endpoint for Horizon/RPC/Friendbot/Lab: the private DNS name in private mode (resolvable inside the VNet), the public FQDN in public mode"
  value       = local.stellar_endpoint
}

output "container_group_private_ip" {
  description = "Private IP of the quickstart container group; null in public mode"
  value       = local.is_private ? azurerm_container_group.stellar.ip_address : null
}

output "container_group_public_ip" {
  description = "Public IP of the quickstart container group; null in private mode"
  value       = local.is_private ? null : azurerm_container_group.stellar.ip_address
}

output "container_group_public_fqdn" {
  description = "Public FQDN ({label}.{region}.azurecontainer.io); null in private mode"
  value       = azurerm_container_group.stellar.fqdn
}

output "vnet_id" {
  description = "ID of the virtual network (for peering from consumer VNets); null in public mode"
  value       = one(azurerm_virtual_network.stellar[*].id)
}

output "vnet_name" {
  description = "Name of the virtual network; null in public mode"
  value       = one(azurerm_virtual_network.stellar[*].name)
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone (for linking additional VNets); null in public mode"
  value       = one(azurerm_private_dns_zone.stellar[*].id)
}

output "vpn_gateway_name" {
  description = "Name of the VPN gateway (needed to generate the VPN client profile); null when the VPN is disabled"
  value       = one(azurerm_virtual_network_gateway.vpn[*].name)
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the P2S VPN endpoint; null when the VPN is disabled"
  value       = one(azurerm_public_ip.vpn_gateway[*].ip_address)
}
