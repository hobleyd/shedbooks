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
  # Required: deploy into a dedicated compartment, not the root tenancy.
  # Create one in OCI Console → Identity → Compartments before running terraform apply.
  description = "OCID of the compartment to deploy into. Must be a dedicated compartment, not the root tenancy."
  type        = string
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
  description = "CIDR ranges allowed to SSH into the instance. Set to your public IP (e.g. [\"203.0.113.1/32\"]). Do not leave as 0.0.0.0/0 in production."
  type        = list(string)

  validation {
    condition     = length(var.ssh_allowed_cidrs) > 0
    error_message = "ssh_allowed_cidrs must contain at least one CIDR block."
  }
}

# ── Images ────────────────────────────────────────────────────────────────────

variable "image_tag" {
  description = "Docker image tag for all Shedbooks images. Use a version tag (e.g. v1.2.0) rather than 'latest' for reproducible production deployments."
  type        = string
  default     = "latest"
}

# ── General ───────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment label applied as a freeform tag"
  type        = string
  default     = "prod"
}
