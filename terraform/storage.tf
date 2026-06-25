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

# ── Customer-managed KMS encryption (optional) ────────────────────────────────
# Both buckets use Oracle-managed encryption by default. To add a customer-managed
# key (CMK), create an OCI Vault + Master Encryption Key, then add to each bucket:
#
#   kms_key_id = oci_kms_key.shedbooks.id
#
# resource "oci_kms_vault" "shedbooks" { ... }
# resource "oci_kms_key" "shedbooks" { ... }
# ──────────────────────────────────────────────────────────────────────────────

# Bucket for entity-scoped JSON backups (downloaded via the admin backup endpoint)
resource "oci_objectstorage_bucket" "backups" {
  compartment_id = local.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "shedbooks-backups"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  freeform_tags  = local.tags
}

# General-purpose bucket for application file storage (receipts, attachments, etc.)
resource "oci_objectstorage_bucket" "data" {
  compartment_id = local.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "shedbooks-data"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  freeform_tags  = local.tags
}

# Lifecycle policy (removed): OCI requires an IAM service policy granting
# objectstorage-<region> permission to manage object-family before lifecycle
# policies can be applied. Omitted here as it is irrelevant for Always Free
# (storage is free within the 10 GB limit regardless of tier).
