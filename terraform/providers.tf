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

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Native Azure Storage backend — the resource group, storage account, and
  # container it points at are created once, out of band, by
  # scripts/bootstrap-azure.sh (chicken-and-egg: the state store can't be
  # provisioned by the same Terraform run that needs it to exist first).
  #
  # use_azuread_auth = true authenticates with an Azure AD token rather than
  # a storage account key — the CI service principal (via OIDC — see
  # ARM_USE_OIDC in terraform.yml) and a locally `az login`-ed developer both
  # already have one, so no storage credential needs to be issued or rotated.
  # The identity used either way needs the "Storage Blob Data Owner" (or
  # Contributor) role on the state storage account.
  #
  # The account/container names are supplied at `tofu init` time via
  # -backend-config=backend.hcl so they never appear in committed code.
  # See scripts/bootstrap-azure.sh (local) and .github/workflows/terraform.yml (CI).
  #
  # To init without remote state during bootstrapping:
  #   tofu init -backend=false
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}

  # No explicit auth method configured here on purpose: the azurerm provider
  # auto-detects it from the environment — a local `az login` session, or in
  # CI the ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID / ARM_USE_OIDC
  # variables set by azure/login (see terraform.yml). Hardcoding use_oidc =
  # true here would break plain local `az login` usage.
}
