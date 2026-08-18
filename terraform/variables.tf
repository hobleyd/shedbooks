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

# ── Azure Authentication ────────────────────────────────────────────────────
# Not declared as variables: the azurerm provider auto-detects its
# credentials from the environment (providers.tf) — a local `az login`
# session, or in CI the ARM_CLIENT_ID / ARM_SUBSCRIPTION_ID / ARM_TENANT_ID /
# ARM_USE_OIDC environment variables set by azure/login (see terraform.yml).
# The azurerm backend uses the same identity via use_azuread_auth.

# ── General ───────────────────────────────────────────────────────────────────

variable "location" {
  description = "Azure region. Kept in Australia to keep financial/member data in-country (GST/ABR integration, .au.auth0.com tenant)."
  type        = string
  default     = "australiaeast"
}

variable "environment" {
  description = "Environment label applied as a tag"
  type        = string
  default     = "prod"
}

variable "resource_group_name" {
  description = "Name of the resource group Terraform manages (separate from the bootstrap resource group holding remote state + ACR — see scripts/bootstrap-azure.sh)."
  type        = string
  default     = "rg-shedbooks-prod"
}

# ── Container Registry (created by scripts/bootstrap-azure.sh, referenced here) ─

variable "acr_resource_group_name" {
  description = "Resource group containing the pre-existing Azure Container Registry created by scripts/bootstrap-azure.sh."
  type        = string
  default     = "rg-shedbooks-bootstrap"
}

variable "acr_name" {
  description = "Name of the pre-existing Azure Container Registry (globally unique, alphanumeric only)."
  type        = string
}

variable "image_tag" {
  description = "Docker image tag for the client/server images (e.g. a git SHA). Use a specific tag rather than 'latest' — changing it is what triggers a new Container Apps revision."
  type        = string
  default     = "latest"
}

# ── PostgreSQL ───────────────────────────────────────────────────────────────

variable "postgres_version" {
  description = "PostgreSQL major version. Must match db/Dockerfile's postgres:16-alpine base."
  type        = string
  default     = "16"
}

variable "postgres_admin_username" {
  description = "Administrator username for the Flexible Server"
  type        = string
  default     = "shedbooks"
}

variable "postgres_admin_password" {
  description = "Administrator password for the Flexible Server. Also used as the app's DB_PASSWORD."
  type        = string
  sensitive   = true
}

variable "postgres_sku_name" {
  description = "Flexible Server compute SKU. B_Standard_B1ms (1 vCore/2GiB, Burstable) comfortably covers this app's traffic; scale up if needed."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Allocated storage in MB. 32768 = 32GB, the smallest tier that supports 16 tuned autogrow."
  type        = number
  default     = 32768
}

variable "postgres_backup_retention_days" {
  description = "Point-in-time-restore backup retention, in days (7-35)."
  type        = number
  default     = 7
}

# ── Container Apps ───────────────────────────────────────────────────────────

variable "server_min_replicas" {
  description = "Minimum replicas for the server app. Pinned to 1 (not 0): avoids stacking a cold start on top of the already-slow O365/Exchange Online sync path, and keeps nginx's cached internal-FQDN resolution valid. See database_migrator.dart's advisory lock for why brief multi-replica overlap during a deploy is still safe."
  type        = number
  default     = 1
}

variable "server_max_replicas" {
  description = "Maximum replicas for the server app. Kept at 1 — this app has no per-request state that requires horizontal scaling at current traffic levels; raise if that changes."
  type        = number
  default     = 1
}

variable "server_cpu" {
  description = "vCPU allocated to the server container"
  type        = number
  default     = 0.5
}

variable "server_memory" {
  description = "Memory allocated to the server container, e.g. '1Gi'"
  type        = string
  default     = "1Gi"
}

variable "client_min_replicas" {
  description = "Minimum replicas for the client (nginx + Flutter web) app. Safe to scale to zero — it's stateless and cold-starts fast."
  type        = number
  default     = 0
}

variable "client_max_replicas" {
  description = "Maximum replicas for the client app."
  type        = number
  default     = 3
}

variable "client_cpu" {
  description = "vCPU allocated to the client container"
  type        = number
  default     = 0.25
}

variable "client_memory" {
  description = "Memory allocated to the client container, e.g. '0.5Gi'"
  type        = string
  default     = "0.5Gi"
}

# ── Application secrets / config ─────────────────────────────────────────────
# These become Container Apps secrets/env vars on the server app — the same
# values that used to populate /opt/shedbooks/.env via cloud-init.

variable "auth0_domain" {
  description = "Auth0 tenant domain, e.g. sharpblue.au.auth0.com"
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 application client ID (baked into the Flutter web build)"
  type        = string
}

variable "auth0_audience" {
  description = "Auth0 API audience identifier"
  type        = string
}

variable "cors_origin" {
  description = "Allowed CORS origin for the server API — the client app's public origin (default ACA FQDN, or the custom domain once bound)."
  type        = string
}

variable "abr_guid" {
  description = "Australian Business Register web service GUID (optional)"
  type        = string
  default     = ""
}

variable "encryption_key" {
  description = "Application-level encryption key (32+ random chars) used to encrypt sensitive stored fields (e.g. O365SyncSettings PFX)."
  type        = string
  sensitive   = true
}
