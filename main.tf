locals {
  name_prefix = "${var.project_name}-${var.environment}"

  is_private = var.network_access == "private"

  create_resource_group = var.resource_group_name == null

  resource_group_name = local.create_resource_group ? azurerm_resource_group.stellar[0].name : data.azurerm_resource_group.existing[0].name
  location            = local.create_resource_group ? var.location : coalesce(var.location, data.azurerm_resource_group.existing[0].location)

  common_tags = merge(
    {
      provisioned_by = "terraform"
      environment    = var.environment
      project        = var.project_name
      managed_by     = "obsrvr-infra"
    },
    var.tags
  )

  aad_tenant_url = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/"
  aad_issuer_url = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"

  stellar_fqdn   = "${var.dns_record_name}.${var.private_dns_zone_name}"
  dns_name_label = coalesce(var.dns_name_label, local.name_prefix)

  stellar_endpoint = local.is_private ? "http://${local.stellar_fqdn}:8000" : "http://${azurerm_container_group.stellar.fqdn}:8000"
}

# Tenant of the current credentials, used for the P2S VPN Entra ID auth URLs.
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Resource group: use the supplied one, or create our own
# ---------------------------------------------------------------------------

data "azurerm_resource_group" "existing" {
  count = local.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "stellar" {
  count    = local.create_resource_group ? 1 : 0
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    precondition {
      condition     = var.location != null
      error_message = "location must be set when the module creates the resource group (resource_group_name = null)."
    }
  }
}

# ---------------------------------------------------------------------------
# Network (private mode only; public mode has no VNet at all)
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "stellar" {
  count = local.is_private ? 1 : 0

  name                = "vnet-${local.name_prefix}"
  address_space       = [var.vnet_cidr]
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = local.common_tags
}

resource "azurerm_subnet" "aci" {
  count = local.is_private ? 1 : 0

  name                 = "snet-aci"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.stellar[0].name
  address_prefixes     = [var.aci_subnet_cidr]

  delegation {
    name = "aci"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "aci" {
  count = local.is_private ? 1 : 0

  name                = "nsg-${local.name_prefix}-aci"
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = local.common_tags

  dynamic "security_rule" {
    for_each = var.enable_vpn_gateway ? [var.vpn_client_address_pool] : []

    content {
      name                       = "AllowStellarFromVpnClients"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8000"
      source_address_prefix      = security_rule.value
      destination_address_prefix = var.aci_subnet_cidr
    }
  }

  security_rule {
    name                       = "AllowStellarFromVnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = var.aci_subnet_cidr
  }

  dynamic "security_rule" {
    for_each = { for idx, cidr in var.additional_allowed_cidrs : idx => cidr }

    content {
      name                       = "AllowStellarFromAdditional${security_rule.key}"
      priority                   = 120 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8000"
      source_address_prefix      = security_rule.value
      destination_address_prefix = var.aci_subnet_cidr
    }
  }

  security_rule {
    name                       = "DenyAllOtherInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aci" {
  count = local.is_private ? 1 : 0

  subnet_id                 = azurerm_subnet.aci[0].id
  network_security_group_id = azurerm_network_security_group.aci[0].id
}

# ---------------------------------------------------------------------------
# Stellar quickstart container
# Private mode: VNet-injected, private IP only.
# Public mode: public IP + FQDN, no VNet — every service internet-reachable.
# ---------------------------------------------------------------------------

resource "azurerm_container_group" "stellar" {
  name                = "ci-${local.name_prefix}"
  location            = local.location
  resource_group_name = local.resource_group_name
  os_type             = "Linux"
  ip_address_type     = local.is_private ? "Private" : "Public"
  dns_name_label      = local.is_private ? null : local.dns_name_label
  subnet_ids          = local.is_private ? [azurerm_subnet.aci[0].id] : null
  restart_policy      = "Always"
  tags                = local.common_tags

  lifecycle {
    precondition {
      condition     = local.is_private || !var.enable_vpn_gateway
      error_message = "enable_vpn_gateway requires network_access = \"private\"."
    }
  }

  container {
    name   = "quickstart"
    image  = var.quickstart_image
    cpu    = var.container_cpu
    memory = var.container_memory

    # Overrides the image entrypoint; quickstart's /start expects the
    # network flag as its argument.
    commands = ["/start", "--${var.stellar_network}"]

    ports {
      port     = 8000
      protocol = "TCP"
    }
  }
}

# ---------------------------------------------------------------------------
# Private DNS (private mode only; public mode gets an azurecontainer.io FQDN)
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "stellar" {
  count = local.is_private ? 1 : 0

  name                = var.private_dns_zone_name
  resource_group_name = local.resource_group_name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "stellar" {
  count = local.is_private ? 1 : 0

  name                  = "dnslink-${local.name_prefix}"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.stellar[0].name
  virtual_network_id    = azurerm_virtual_network.stellar[0].id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_a_record" "stellar" {
  count = local.is_private ? 1 : 0

  name                = var.dns_record_name
  zone_name           = azurerm_private_dns_zone.stellar[0].name
  resource_group_name = local.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_group.stellar.ip_address]
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# Point-to-Site VPN gateway (optional; Entra ID auth, OpenVPN)
# ---------------------------------------------------------------------------

# The VPN gateway requires a subnet with this exact name.
resource "azurerm_subnet" "gateway" {
  count = local.is_private && var.enable_vpn_gateway ? 1 : 0

  name                 = "GatewaySubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.stellar[0].name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# This public IP is the VPN endpoint only; the container itself is never
# publicly reachable.
resource "azurerm_public_ip" "vpn_gateway" {
  count = local.is_private && var.enable_vpn_gateway ? 1 : 0

  name                = "pip-${local.name_prefix}-vpngw"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count = local.is_private && var.enable_vpn_gateway ? 1 : 0

  name                = "vgw-${local.name_prefix}"
  location            = local.location
  resource_group_name = local.resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  generation          = "Generation1"
  tags                = local.common_tags

  ip_configuration {
    name                          = "vpngw-ipconfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway[0].id
  }

  vpn_client_configuration {
    address_space        = [var.vpn_client_address_pool]
    vpn_client_protocols = ["OpenVPN"]
    aad_tenant           = local.aad_tenant_url
    aad_audience         = var.vpn_aad_audience
    aad_issuer           = local.aad_issuer_url
  }
}
