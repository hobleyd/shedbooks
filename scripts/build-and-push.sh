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

# Build Docker images for linux/amd64 (Azure Container Apps) and push to ACR.
# Auth0 build args are baked into the client image at build time.
#
# Usage:
#   AUTH0_DOMAIN=x AUTH0_CLIENT_ID=y AUTH0_AUDIENCE=z ACR_NAME=acrshedbooks ./scripts/build-and-push.sh
#   TAG=v1.2.3 ACR_NAME=acrshedbooks ./scripts/build-and-push.sh   # tag other than 'latest'
#
# The server image is not rebuilt here — db/Dockerfile's custom Postgres
# image no longer exists (see terraform/database.tf: Azure Database for
# PostgreSQL Flexible Server replaces it), so this only builds server + client.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ACR_NAME="${ACR_NAME:?Set ACR_NAME to the Azure Container Registry name (e.g. acrshedbooks)}"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
TAG="${TAG:-latest}"

AUTH0_DOMAIN="${AUTH0_DOMAIN:?AUTH0_DOMAIN must be set (baked into the Flutter web build)}"
AUTH0_CLIENT_ID="${AUTH0_CLIENT_ID:?AUTH0_CLIENT_ID must be set}"
AUTH0_AUDIENCE="${AUTH0_AUDIENCE:?AUTH0_AUDIENCE must be set}"
API_URL="${API_URL:-/api}"

echo "ACR   : $ACR_LOGIN_SERVER"
echo "Tag   : $TAG"
echo ""

echo "→ Logging in to ACR (via az CLI / AAD token — no admin credentials)..."
az acr login --name "$ACR_NAME"

# ── Build ─────────────────────────────────────────────────────────────────────

echo "→ Building server image (linux/amd64)..."
docker build \
  --platform linux/amd64 \
  -t "$ACR_LOGIN_SERVER/server:$TAG" \
  "$PROJECT_ROOT/server"

echo "→ Building client image (linux/amd64)..."
docker build \
  --platform linux/amd64 \
  --build-arg AUTH0_DOMAIN="$AUTH0_DOMAIN" \
  --build-arg AUTH0_CLIENT_ID="$AUTH0_CLIENT_ID" \
  --build-arg AUTH0_AUDIENCE="$AUTH0_AUDIENCE" \
  --build-arg API_URL="$API_URL" \
  -t "$ACR_LOGIN_SERVER/client:$TAG" \
  "$PROJECT_ROOT/client"

# ── Push ──────────────────────────────────────────────────────────────────────

echo ""
echo "→ Pushing images to ACR..."
docker push "$ACR_LOGIN_SERVER/server:$TAG"
docker push "$ACR_LOGIN_SERVER/client:$TAG"

echo ""
echo "Done. Images pushed:"
echo "  $ACR_LOGIN_SERVER/server:$TAG"
echo "  $ACR_LOGIN_SERVER/client:$TAG"
echo ""
echo "Run 'tofu apply -var image_tag=$TAG' (in terraform/) to roll out a new Container Apps revision."
