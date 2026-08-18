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

# The ACR itself is created once, out of band, by scripts/bootstrap-azure.sh
# — not here. Creating it in the same apply as the container apps that pull
# from it is a chicken-and-egg problem: the first apply would try to create
# a revision from an image that was never pushed, since nothing has been
# built yet. Referencing it as a data source keeps the registry's lifecycle
# independent of (and unaffected by) this stack's applies/destroys.
data "azurerm_container_registry" "shedbooks" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

# A user-assigned identity, granted AcrPull *before* either container app is
# created (see the explicit depends_on below) — using a system-assigned
# identity instead would create an ordering problem, since its principal_id
# only exists after the container app itself is created, by which point ACA
# has already tried (and failed) to pull the image once.
resource "azurerm_user_assigned_identity" "aca_acr_pull" {
  name                = "shedbooks-aca-acr-pull"
  resource_group_name = azurerm_resource_group.shedbooks.name
  location            = azurerm_resource_group.shedbooks.location
  tags                = local.tags
}

# NOTE: creating this role assignment requires the identity running
# Terraform (the CI service principal — see terraform.yml) to hold at least
# "User Access Administrator" on the ACR or its resource group. Plain
# "Contributor" cannot create role assignments.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.shedbooks.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_acr_pull.principal_id
}

resource "azurerm_log_analytics_workspace" "shedbooks" {
  name                = "shedbooks-logs"
  resource_group_name = azurerm_resource_group.shedbooks.name
  location            = azurerm_resource_group.shedbooks.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_container_app_environment" "shedbooks" {
  name                       = "shedbooks-env"
  resource_group_name        = azurerm_resource_group.shedbooks.name
  location                   = azurerm_resource_group.shedbooks.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.shedbooks.id

  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = false # the client app needs external ingress

  tags = local.tags
}

# ── Server (Dart/Shelf API) ──────────────────────────────────────────────────
# Internal ingress only — never reachable from outside the Container Apps
# Environment/VNet. allow_insecure_connections lets nginx (the client app)
# call it over plain http on this private hop, avoiding any need for nginx
# to trust ACA's internal TLS certificate chain.
resource "azurerm_container_app" "server" {
  name                         = "shedbooks-server"
  resource_group_name          = azurerm_resource_group.shedbooks.name
  container_app_environment_id = azurerm_container_app_environment.shedbooks.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca_acr_pull.id]
  }

  registry {
    server   = data.azurerm_container_registry.shedbooks.login_server
    identity = azurerm_user_assigned_identity.aca_acr_pull.id
  }

  ingress {
    external_enabled           = false
    target_port                = 8080
    allow_insecure_connections = true
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "db-password"
    value = var.postgres_admin_password
  }

  secret {
    name  = "encryption-key"
    value = var.encryption_key
  }

  template {
    min_replicas = var.server_min_replicas
    max_replicas = var.server_max_replicas

    container {
      name   = "server"
      image  = "${data.azurerm_container_registry.shedbooks.login_server}/server:${var.image_tag}"
      cpu    = var.server_cpu
      memory = var.server_memory

      env {
        name  = "PORT"
        value = "8080"
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.shedbooks.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.shedbooks.name
      }
      env {
        name  = "DB_USER"
        value = var.postgres_admin_username
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name        = "ENCRYPTION_KEY"
        secret_name = "encryption-key"
      }
      env {
        name  = "MIGRATIONS_DIR"
        value = "/app/migrations"
      }
      env {
        name  = "AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "AUTH0_AUDIENCE"
        value = var.auth0_audience
      }
      env {
        name  = "CORS_ORIGIN"
        value = var.cors_origin
      }
      env {
        name  = "ABR_GUID"
        value = var.abr_guid
      }
    }
  }

  tags = local.tags

  # Also waits on the extension allow-list (database.tf) — the server runs
  # DatabaseMigrator.migrate() on startup, which needs uuid-ossp allow-listed
  # before its first CREATE EXTENSION statement, or the container crash-loops.
  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_postgresql_flexible_server_configuration.extensions,
  ]
}

# ── Client (nginx + Flutter web) ─────────────────────────────────────────────
# External ingress — TLS terminated here by Azure's managed certificate on
# the default *.azurecontainerapps.io FQDN. Binding a custom domain is a
# manual post-apply step; see outputs.tf's next_steps.
resource "azurerm_container_app" "client" {
  name                         = "shedbooks-client"
  resource_group_name          = azurerm_resource_group.shedbooks.name
  container_app_environment_id = azurerm_container_app_environment.shedbooks.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca_acr_pull.id]
  }

  registry {
    server   = data.azurerm_container_registry.shedbooks.login_server
    identity = azurerm_user_assigned_identity.aca_acr_pull.id
  }

  ingress {
    external_enabled           = true
    target_port                = 80
    allow_insecure_connections = false
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.client_min_replicas
    max_replicas = var.client_max_replicas

    container {
      name   = "client"
      image  = "${data.azurerm_container_registry.shedbooks.login_server}/client:${var.image_tag}"
      cpu    = var.client_cpu
      memory = var.client_memory

      # Substituted into nginx.conf.template at container start (see
      # client/Dockerfile) — the server app's private, VNet-internal FQDN.
      env {
        name  = "SERVER_INTERNAL_FQDN"
        value = azurerm_container_app.server.ingress[0].fqdn
      }
    }
  }

  tags = local.tags

  depends_on = [azurerm_role_assignment.acr_pull]
}
