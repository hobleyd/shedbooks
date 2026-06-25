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
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  # HTTP backend using an OCI Pre-Authenticated Request (PAR).
  # OCI's S3-compatible API does not support AWS chunked transfer encoding,
  # so the S3 backend cannot be used. The HTTP backend with a PAR URL avoids
  # all AWS SDK compatibility issues.
  #
  # The PAR URL (address) is the only credential needed — it grants read/write
  # access to the single state object. It is supplied at `terraform init` time
  # via -backend-config=backend.hcl so it never appears in committed code.
  # See scripts/bootstrap-state.sh (local) and .github/workflows/terraform.yml (CI).
  #
  # To init without remote state during bootstrapping:
  #   terraform init -backend=false
  backend "http" {
    update_method = "PUT"
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
