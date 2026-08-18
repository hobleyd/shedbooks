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

# Creates the one-time Azure resources that Terraform itself can't create
# (a classic chicken-and-egg: the remote state store has to exist before
# `tofu init` can use it, and the container registry has to exist — with at
# least one image already in it — before the container apps stack can
# reference an image to pull). Run this ONCE per environment.
#
# Prerequisites:
#   - Azure CLI installed and logged in (`az login`) with rights to create
#     resource groups, storage accounts, and role assignments.
#
# Usage:
#   LOCATION=australiaeast STATE_STORAGE_ACCOUNT=stshedbookstfstate \
#   ACR_NAME=acrshedbooks ./scripts/bootstrap-azure.sh
#
# Optional:
#   CI_SERVICE_PRINCIPAL_OBJECT_ID — object ID of the GitHub Actions OIDC
#     app registration's service principal (see .github/workflows/terraform.yml).
#     If set, grants it the roles it needs to run `tofu plan`/`apply` and
#     push images. If unset, print the az commands to run once that SP exists.

set -euo pipefail

BOOTSTRAP_RESOURCE_GROUP="${BOOTSTRAP_RESOURCE_GROUP:-rg-shedbooks-bootstrap}"
LOCATION="${LOCATION:-australiaeast}"
STATE_STORAGE_ACCOUNT="${STATE_STORAGE_ACCOUNT:?Set STATE_STORAGE_ACCOUNT (globally unique, lowercase, 3-24 chars, e.g. stshedbookstfstate)}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
ACR_NAME="${ACR_NAME:?Set ACR_NAME (globally unique, alphanumeric, e.g. acrshedbooks)}"
CI_SERVICE_PRINCIPAL_OBJECT_ID="${CI_SERVICE_PRINCIPAL_OBJECT_ID:-}"

echo "=== Azure Bootstrap ==="
echo "Resource group : $BOOTSTRAP_RESOURCE_GROUP"
echo "Location       : $LOCATION"
echo "State storage  : $STATE_STORAGE_ACCOUNT / $STATE_CONTAINER"
echo "ACR            : $ACR_NAME"
echo ""

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
CURRENT_USER_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"

echo "→ Creating bootstrap resource group..."
az group create --name "$BOOTSTRAP_RESOURCE_GROUP" --location "$LOCATION" -o none

echo "→ Creating Terraform state storage account (AAD auth only, no shared keys)..."
az storage account create \
  --name "$STATE_STORAGE_ACCOUNT" \
  --resource-group "$BOOTSTRAP_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  -o none

STORAGE_ACCOUNT_ID="$(az storage account show --name "$STATE_STORAGE_ACCOUNT" --resource-group "$BOOTSTRAP_RESOURCE_GROUP" --query id -o tsv)"

echo "→ Granting yourself Storage Blob Data Owner (needed for AAD-authenticated blob access)..."
az role assignment create \
  --assignee-object-id "$CURRENT_USER_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Owner" \
  --scope "$STORAGE_ACCOUNT_ID" \
  -o none 2>/dev/null || echo "  (already assigned, or check manually)"

# Role assignments can take a few seconds to propagate before they're usable.
echo "→ Waiting for role assignment to propagate..."
sleep 20

echo "→ Creating state container..."
az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STATE_STORAGE_ACCOUNT" \
  --auth-mode login \
  -o none

echo "→ Creating Azure Container Registry (admin account disabled — pulls use a managed identity, see terraform/container_apps.tf)..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$BOOTSTRAP_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Basic \
  --admin-enabled false \
  -o none

if [[ -n "$CI_SERVICE_PRINCIPAL_OBJECT_ID" ]]; then
  echo "→ Granting the CI service principal AcrPush (to build/push images)..."
  az role assignment create \
    --assignee-object-id "$CI_SERVICE_PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "AcrPush" \
    --scope "$(az acr show --name "$ACR_NAME" --query id -o tsv)" \
    -o none

  echo "→ Granting the CI service principal Storage Blob Data Owner (for tfstate)..."
  az role assignment create \
    --assignee-object-id "$CI_SERVICE_PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Owner" \
    --scope "$STORAGE_ACCOUNT_ID" \
    -o none

  # Subscription-scoped and intentionally broad for a first bootstrap —
  # Contributor to manage resources, User Access Administrator because
  # terraform/container_apps.tf creates an AcrPull role assignment for the
  # container apps' managed identity (plain Contributor can't create role
  # assignments). Once terraform/ has been applied at least once and
  # rg-shedbooks-prod exists, narrow both to that resource group's scope
  # instead: az role assignment create ... --scope "$(az group show --name rg-shedbooks-prod --query id -o tsv)"
  echo "→ Granting the CI service principal Contributor + User Access Administrator on the subscription..."
  az role assignment create \
    --assignee-object-id "$CI_SERVICE_PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    -o none
  az role assignment create \
    --assignee-object-id "$CI_SERVICE_PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "User Access Administrator" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    -o none
else
  echo ""
  echo "  CI_SERVICE_PRINCIPAL_OBJECT_ID not set — skipping CI role grants."
  echo "  Once the GitHub Actions OIDC app registration exists (see terraform.yml"
  echo "  for the federated credential subjects it needs), re-run with:"
  echo "    CI_SERVICE_PRINCIPAL_OBJECT_ID=<object-id> STATE_STORAGE_ACCOUNT=$STATE_STORAGE_ACCOUNT ACR_NAME=$ACR_NAME ./scripts/bootstrap-azure.sh"
fi

BACKEND_HCL="$(dirname "$0")/../terraform/backend.hcl"

echo ""
echo "=== Writing terraform/backend.hcl ==="
cat > "$BACKEND_HCL" <<EOF
resource_group_name  = "$BOOTSTRAP_RESOURCE_GROUP"
storage_account_name = "$STATE_STORAGE_ACCOUNT"
container_name        = "$STATE_CONTAINER"
key                    = "shedbooks.tfstate"
EOF
echo "  Written to $BACKEND_HCL"
echo "  (this file is gitignored — do not commit it)"

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Initialise Terraform with the azurerm backend:"
echo "     cd terraform && tofu init -backend-config=backend.hcl"
echo ""
echo "2. Set these GitHub Actions repo variables (Settings → Variables → Actions):"
echo "     ACR_NAME              = $ACR_NAME"
echo "     ACR_RESOURCE_GROUP    = $BOOTSTRAP_RESOURCE_GROUP"
echo "     TF_STATE_RESOURCE_GROUP  = $BOOTSTRAP_RESOURCE_GROUP"
echo "     TF_STATE_STORAGE_ACCOUNT = $STATE_STORAGE_ACCOUNT"
echo "     TF_STATE_CONTAINER       = $STATE_CONTAINER"
echo ""
echo "3. Copy terraform/terraform.tfvars.example to terraform.tfvars and fill in"
echo "   acr_name = \"$ACR_NAME\" / acr_resource_group_name = \"$BOOTSTRAP_RESOURCE_GROUP\""
echo "   plus the Postgres/Auth0/encryption secrets."
echo ""
echo "4. Build + push the first images so the container apps stack has"
echo "   something to pull on its first apply:"
echo "     AUTH0_DOMAIN=x AUTH0_CLIENT_ID=y AUTH0_AUDIENCE=z ACR_NAME=$ACR_NAME ../scripts/build-and-push.sh"
echo ""
echo "5. Apply:  cd terraform && tofu apply"
