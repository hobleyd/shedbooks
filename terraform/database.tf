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

# Private (VNet-integrated) Flexible Server — no public endpoint. Reachable
# only from the delegated subnet it sits in and the Container Apps
# Environment subnet in the same VNet (network.tf). Replaces the old
# self-managed db/ container image + manually generated SSL certs entirely;
# Azure handles TLS, patching, and backups.
resource "azurerm_postgresql_flexible_server" "shedbooks" {
  name                = "shedbooks-postgres"
  resource_group_name = azurerm_resource_group.shedbooks.name
  location            = azurerm_resource_group.shedbooks.location

  version = var.postgres_version

  # Not set on the original apply, so Azure auto-assigned one (zone "1")
  # and every subsequent apply then tried to "change" it back to unset,
  # which the API rejects outright without an HA-zone swap. Pinned to what
  # was actually provisioned to remove the drift.
  zone = "1"

  delegated_subnet_id = azurerm_subnet.postgres.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  # Azure's API rejects VNet integration unless this is explicitly false —
  # it does not infer "no public access" just from delegated_subnet_id being
  # set (confirmed by a real apply: ConflictingPublicNetworkAccessAndVirtualNetworkConfiguration).
  public_network_access_enabled = false

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  storage_mb                   = var.postgres_storage_mb
  sku_name                     = var.postgres_sku_name
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = false

  tags = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# The app connects with DB_NAME=shedbooks (see container_apps.tf) — the
# Flexible Server only creates a default `postgres` database, so this must
# be created explicitly.
resource "azurerm_postgresql_flexible_server_database" "shedbooks" {
  name      = "shedbooks"
  server_id = azurerm_postgresql_flexible_server.shedbooks.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Flexible Server requires extensions to be explicitly allow-listed at the
# server level before CREATE EXTENSION is permitted — confirmed by a real
# deploy: migration 001_create_general_ledger.sql's `CREATE EXTENSION
# IF NOT EXISTS "uuid-ossp"` failed with "extension \"uuid-ossp\" is not
# allow-listed for users in Azure Database for PostgreSQL". Self-hosted
# Postgres never had this restriction. Add further extensions here (comma-
# separated) if a later migration needs one.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.shedbooks.id
  value     = "UUID-OSSP"
}
