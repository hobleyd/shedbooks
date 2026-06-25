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
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  # Partial backend configuration — non-secret values only.
  # The remaining values (region, endpoint, access_key, secret_key) are supplied
  # via -backend-config flags at `terraform init` time so they never appear in
  # committed code. See scripts/bootstrap-state.sh (local) and
  # .github/workflows/terraform.yml (CI).
  #
  # First-time setup: run scripts/bootstrap-state.sh, then terraform init with
  # the flags it prints. To init without remote state during bootstrapping:
  #   terraform init -backend=false
  backend "s3" {
    bucket                      = "shedbooks-tf-state"
    key                         = "shedbooks/terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
