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

# ── OCI Authentication ────────────────────────────────────────────────────────

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user running Terraform"
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint for OCI authentication"
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API private key PEM file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI region identifier (e.g. ap-sydney-1, us-ashburn-1)"
  type        = string
}

# ── Compartment ───────────────────────────────────────────────────────────────

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy into. Defaults to root (tenancy) compartment."
  type        = string
  default     = null
}

# ── Compute ───────────────────────────────────────────────────────────────────

variable "ssh_public_key" {
  description = "SSH public key content for instance access"
  type        = string
}

variable "instance_ocpus" {
  description = "OCPUs for the compute instance. Always Free A1 allows up to 4 total."
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory in GB for the compute instance. Always Free A1 allows up to 24 GB total."
  type        = number
  default     = 12
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB. Always Free allows 200 GB total block storage."
  type        = number
  default     = 50
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed for SSH access. Restrict to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── OCIR (Container Registry) ─────────────────────────────────────────────────

variable "ocir_auth_token" {
  description = "OCI auth token for OCIR Docker login. Generate in OCI Console → User Settings → Auth Tokens."
  type        = string
  sensitive   = true
}

variable "ocir_username" {
  description = "OCI username for OCIR login. Use your email for IDCS/federated users, or IAM username for native users."
  type        = string
}

variable "use_idcs" {
  description = "Whether the OCI user authenticates via IDCS federation (true) or native IAM (false)."
  type        = bool
  default     = true
}

# ── General ───────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment label applied as a freeform tag"
  type        = string
  default     = "prod"
}
