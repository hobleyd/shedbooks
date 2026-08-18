# Copyright (C) 2026 David Hobley
#
# This file is part of Shedbooks.
#
# Shedbooks is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Shedbooks is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

locals {
  tags = { project = "shedbooks", environment = var.environment }
}

resource "azurerm_resource_group" "shedbooks" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "shedbooks" {
  name                = "shedbooks-vnet"
  resource_group_name = azurerm_resource_group.shedbooks.name
  location            = azurerm_resource_group.shedbooks.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

# Container Apps Environment infrastructure subnets require /21 or larger.
# Sized to exactly that floor since this VNet is dedicated to Shedbooks and
# 10.0.0.0/16 leaves plenty of room either way.
resource "azurerm_subnet" "container_apps" {
  name                 = "shedbooks-aca-subnet"
  resource_group_name  = azurerm_resource_group.shedbooks.name
  virtual_network_name = azurerm_virtual_network.shedbooks.name
  address_prefixes     = ["10.0.0.0/21"]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Postgres Flexible Server only requires a /28, sized up to /24 for headroom.
resource "azurerm_subnet" "postgres" {
  name                 = "shedbooks-postgres-subnet"
  resource_group_name  = azurerm_resource_group.shedbooks.name
  virtual_network_name = azurerm_virtual_network.shedbooks.name
  address_prefixes     = ["10.0.8.0/24"]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# "privatelink.postgres.database.azure.com" is the convention for Private
# Endpoint/Private Link access — a different connectivity model. This server
# uses VNet integration (delegated_subnet_id in database.tf) instead, whose
# required zone name is any label ending in ".postgres.database.azure.com"
# (Microsoft's own Terraform tutorial uses e.g. "<name>-pdz.postgres.database.azure.com").
resource "azurerm_private_dns_zone" "postgres" {
  name                = "shedbooks.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.shedbooks.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "shedbooks-postgres-link"
  resource_group_name   = azurerm_resource_group.shedbooks.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.shedbooks.id
  tags                  = local.tags
}
