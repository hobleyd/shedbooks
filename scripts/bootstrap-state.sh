#!/usr/bin/env bash
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

# Create the Terraform remote state bucket in OCI Object Storage.
# Run this ONCE before enabling the backend block in terraform/providers.tf.
#
# Prerequisites:
#   - OCI CLI configured (oci setup config) with admin permissions
#   - jq installed
#
# Usage:
#   COMPARTMENT_OCID=ocid1.compartment... OCI_REGION=ap-sydney-1 ./scripts/bootstrap-state.sh

set -euo pipefail

COMPARTMENT_OCID="${COMPARTMENT_OCID:?Set COMPARTMENT_OCID to the target compartment OCID}"
OCI_REGION="${OCI_REGION:-ap-sydney-1}"
BUCKET_NAME="shedbooks-tf-state"
USER_OCID="${USER_OCID:-$(oci iam user list --all 2>/dev/null | jq -r '.data[0].id' || echo "")}"

echo "=== Terraform State Bootstrap ==="
echo "Region     : $OCI_REGION"
echo "Compartment: $COMPARTMENT_OCID"
echo "Bucket     : $BUCKET_NAME"
echo ""

# Get tenancy namespace (needed for the S3-compat endpoint)
NAMESPACE="$(oci os ns get --region "$OCI_REGION" | jq -r '.data')"
echo "Namespace  : $NAMESPACE"
echo ""

# Create the bucket (idempotent — errors if already exists, which is fine)
echo "→ Creating state bucket..."
if oci os bucket create \
  --compartment-id "$COMPARTMENT_OCID" \
  --name "$BUCKET_NAME" \
  --namespace "$NAMESPACE" \
  --versioning Enabled \
  --region "$OCI_REGION" 2>/dev/null; then
  echo "  Bucket created: $BUCKET_NAME"
else
  echo "  Bucket already exists (or creation failed — check OCI Console)"
fi

# Create a Pre-Authenticated Request (PAR) for the state object.
# PAR URL grants read/write access to terraform.tfstate without exposing IAM credentials.
# OCI's S3-compat API does not support AWS chunked encoding, so the HTTP backend + PAR
# is used instead of the S3 backend.
echo ""
echo "→ Creating Pre-Authenticated Request for terraform state..."
PAR_EXPIRY="2036-01-01T00:00:00+00:00"  # 10-year PAR; rotate if security requires it
PAR_RESPONSE="$(oci os preauth-request create \
  --bucket-name "$BUCKET_NAME" \
  --namespace "$NAMESPACE" \
  --name "terraform-state-$(date +%Y%m%d)" \
  --access-type "ObjectReadWrite" \
  --time-expires "$PAR_EXPIRY" \
  --object-name "terraform.tfstate" \
  --region "$OCI_REGION" 2>/dev/null || echo "")"

if [[ -n "$PAR_RESPONSE" ]]; then
  PAR_PATH="$(echo "$PAR_RESPONSE" | jq -r '.data["full-path"]')"
  TF_STATE_URL="https://objectstorage.${OCI_REGION}.oraclecloud.com${PAR_PATH}"
  echo "  PAR URL: $TF_STATE_URL"
  echo "  *** Save this URL — it is the only credential needed for state access ***"
else
  echo "  Could not create PAR automatically."
  echo "  Create one manually in OCI Console:"
  echo "    Object Storage → shedbooks-tf-state → Pre-Authenticated Requests → Create"
  echo "    Access Type: Object Read/Write, Object Name: terraform.tfstate"
  TF_STATE_URL="https://objectstorage.${OCI_REGION}.oraclecloud.com/p/<PAR-token>/n/${NAMESPACE}/b/${BUCKET_NAME}/o/terraform.tfstate"
fi

BACKEND_HCL="$(dirname "$0")/../terraform/backend.hcl"

echo ""
echo "=== Writing terraform/backend.hcl ==="
cat > "$BACKEND_HCL" <<EOF
address       = "$TF_STATE_URL"
update_method = "PUT"
EOF
echo "  Written to $BACKEND_HCL"
echo "  (this file is gitignored — do not commit it)"

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Initialise Terraform with the HTTP backend:"
echo "     cd terraform && tofu init -backend-config=backend.hcl"
echo ""
echo "   To migrate existing local or errored state to the new backend:"
echo "     tofu state push errored.tfstate   # if errored.tfstate exists"
echo "     tofu init -backend-config=backend.hcl -migrate-state"
echo ""
echo "2. Replace the GitHub Actions secret TF_STATE_URL with:"
echo "     $TF_STATE_URL"
echo ""
echo "   (Remove the old secrets TF_STATE_NAMESPACE, TF_STATE_ACCESS_KEY, TF_STATE_SECRET_KEY"
echo "    — they are no longer used by the HTTP backend.)"
echo ""
echo "3. Delete local state files once migration is confirmed:"
echo "     rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup terraform/errored.tfstate"
