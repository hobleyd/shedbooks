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

# Build Docker images for linux/arm64 (OCI A1 Flex) and push to OCIR.
# Auth0 build args are baked into the client image at build time.
#
# Usage:
#   AUTH0_DOMAIN=x AUTH0_CLIENT_ID=y AUTH0_AUDIENCE=z ./scripts/build-and-push.sh
#   TAG=v1.2.3 ./scripts/build-and-push.sh   # tag other than 'latest'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Resolve OCIR prefix from terraform output or environment
if [[ -z "${OCIR_PREFIX:-}" ]]; then
  echo "→ Reading OCIR prefix from terraform output..."
  OCIR_PREFIX="$(cd "$TERRAFORM_DIR" && tofu output -raw ocir_prefix)"
fi

TAG="${TAG:-latest}"

AUTH0_DOMAIN="${AUTH0_DOMAIN:?AUTH0_DOMAIN must be set (baked into the Flutter web build)}"
AUTH0_CLIENT_ID="${AUTH0_CLIENT_ID:?AUTH0_CLIENT_ID must be set}"
AUTH0_AUDIENCE="${AUTH0_AUDIENCE:?AUTH0_AUDIENCE must be set}"
API_URL="${API_URL:-/api}"

echo "OCIR prefix : $OCIR_PREFIX"
echo "Tag         : $TAG"
echo ""

# ── Build ─────────────────────────────────────────────────────────────────────

echo "→ Building db image (linux/arm64)..."
docker build \
  --platform linux/arm64 \
  -t "$OCIR_PREFIX/db:$TAG" \
  "$PROJECT_ROOT/db"

echo "→ Building server image (linux/arm64)..."
docker build \
  --platform linux/arm64 \
  -t "$OCIR_PREFIX/server:$TAG" \
  "$PROJECT_ROOT/server"

echo "→ Building client image (linux/arm64)..."
docker build \
  --platform linux/arm64 \
  --build-arg AUTH0_DOMAIN="$AUTH0_DOMAIN" \
  --build-arg AUTH0_CLIENT_ID="$AUTH0_CLIENT_ID" \
  --build-arg AUTH0_AUDIENCE="$AUTH0_AUDIENCE" \
  --build-arg API_URL="$API_URL" \
  -t "$OCIR_PREFIX/client:$TAG" \
  "$PROJECT_ROOT/client"

# ── Push ──────────────────────────────────────────────────────────────────────

echo ""
echo "→ Pushing images to OCIR..."
docker push "$OCIR_PREFIX/db:$TAG"
docker push "$OCIR_PREFIX/server:$TAG"
docker push "$OCIR_PREFIX/client:$TAG"

echo ""
echo "Done. Images pushed:"
echo "  $OCIR_PREFIX/db:$TAG"
echo "  $OCIR_PREFIX/server:$TAG"
echo "  $OCIR_PREFIX/client:$TAG"
echo ""
echo "Run ./scripts/deploy.sh to deploy to the OCI instance."
