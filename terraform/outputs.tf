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

output "client_fqdn" {
  description = "Public FQDN of the client app (default *.azurecontainerapps.io domain)"
  value       = azurerm_container_app.client.ingress[0].fqdn
}

output "server_internal_fqdn" {
  description = "Internal-only FQDN of the server app, reachable only from inside the Container Apps Environment"
  value       = azurerm_container_app.server.ingress[0].fqdn
}

output "postgres_fqdn" {
  description = "Private FQDN of the Postgres Flexible Server (reachable only from within the VNet)"
  value       = azurerm_postgresql_flexible_server.shedbooks.fqdn
}

output "acr_login_server" {
  description = "Login server hostname of the (pre-existing, bootstrap-created) Azure Container Registry"
  value       = data.azurerm_container_registry.shedbooks.login_server
}

output "acr_image_server" {
  description = "Full image reference for the server image at the currently-deployed tag"
  value       = "${data.azurerm_container_registry.shedbooks.login_server}/server:${var.image_tag}"
}

output "acr_image_client" {
  description = "Full image reference for the client image at the currently-deployed tag"
  value       = "${data.azurerm_container_registry.shedbooks.login_server}/client:${var.image_tag}"
}

output "next_steps" {
  description = "Checklist for things this apply does not automate"
  value       = <<-EOT
    1. Update Auth0 (Application → Settings) for the new origin:
         Allowed Callback URLs / Logout URLs / Web Origins → https://${azurerm_container_app.client.ingress[0].fqdn}
         (repeat once a custom domain is bound, step 2 below)

    2. (Optional) Bind a custom domain — Terraform doesn't manage this;
       Azure's managed-certificate binding flow is still evolving in the
       azurerm provider (open upstream bugs), so it's a deliberate manual
       step once DNS is ready:
         a. Add a CNAME (or A record, per Azure's instructions) at your
            registrar pointing your domain at:
              ${azurerm_container_app.client.ingress[0].fqdn}
         b. az containerapp hostname add \
              --hostname <your-domain> \
              --name shedbooks-client --resource-group ${var.resource_group_name}
         c. az containerapp hostname bind \
              --hostname <your-domain> \
              --name shedbooks-client --resource-group ${var.resource_group_name} \
              --environment shedbooks-env --validation-method CNAME
         d. Update var.cors_origin to the new domain and re-apply so the
            server's CORS_ORIGIN matches.

    3. Migrations run automatically at server startup (DatabaseMigrator) —
       no manual migration step, same as before.

    4. Deploys happen via the GitHub Actions workflow: push to main builds
       and pushes new images tagged with the commit SHA, then
       `tofu apply -var image_tag=<sha>` rolls a new Container Apps revision.
  EOT
}
