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

# Create a Customer Secret Key for S3-compat access
echo ""
echo "→ Creating Customer Secret Key for S3-compatible access..."
if [[ -n "$USER_OCID" ]]; then
  SECRET_KEY_RESPONSE="$(oci iam customer-secret-key create \
    --user-id "$USER_OCID" \
    --display-name "terraform-state-$(date +%Y%m%d)" \
    --region "$OCI_REGION" 2>/dev/null || echo "")"

  if [[ -n "$SECRET_KEY_RESPONSE" ]]; then
    KEY_ID="$(echo "$SECRET_KEY_RESPONSE" | jq -r '.data.id')"
    KEY_SECRET="$(echo "$SECRET_KEY_RESPONSE" | jq -r '.data.key')"
    echo ""
    echo "  Customer Secret Key ID    : $KEY_ID"
    echo "  Customer Secret Key Secret: $KEY_SECRET"
    echo ""
    echo "  *** Save the secret above — it is shown ONLY ONCE ***"
  else
    echo "  Could not create Customer Secret Key automatically."
    echo "  Create one manually: OCI Console → User Settings → Customer Secret Keys"
  fi
else
  echo "  Could not determine USER_OCID. Create a Customer Secret Key manually:"
  echo "  OCI Console → User Settings → Customer Secret Keys → Generate Secret Key"
  KEY_ID="<customer-secret-key-id>"
  KEY_SECRET="<customer-secret-key-secret>"
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "The backend block in terraform/providers.tf uses partial configuration."
echo "Run the following to initialise (or migrate existing local state):"
echo ""
echo '  cd terraform && terraform init \'
echo '    -backend-config="region='"$OCI_REGION"'" \'
echo '    -backend-config="endpoint=https://'"$NAMESPACE"'.compat.objectstorage.'"$OCI_REGION"'.oraclecloud.com" \'
echo '    -backend-config="access_key='"${KEY_ID:-<customer-secret-key-id>}"'" \'
echo '    -backend-config="secret_key='"${KEY_SECRET:-<customer-secret-key-secret>}"'" \'
echo '    -migrate-state'
echo ""
echo "Then configure these GitHub Actions secrets/variables:"
echo ""
echo "  Secrets:"
echo "    TF_STATE_NAMESPACE  = $NAMESPACE"
echo "    TF_STATE_ACCESS_KEY = ${KEY_ID:-<customer-secret-key-id>}"
echo "    TF_STATE_SECRET_KEY = ${KEY_SECRET:-<customer-secret-key-secret>}"
echo ""
echo "  Variables (Settings → Variables → Actions):"
echo "    OCI_REGION          = $OCI_REGION"
echo ""
echo "Delete local state files once migration is confirmed:"
echo "  rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup"
