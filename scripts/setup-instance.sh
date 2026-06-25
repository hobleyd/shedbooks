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

# Configure OCIR authentication on the OCI instance.
#
# The auth token is transmitted via SSH only — it never enters Terraform state,
# Terraform variables, or OCI instance user-data/metadata.
#
# Prerequisites:
#   1. terraform apply has completed and the instance is accepting SSH connections
#   2. Generate an auth token in OCI Console: User Settings → Auth Tokens → Generate Token
#
# Usage:
#   OCIR_AUTH_TOKEN=<token> OCIR_USERNAME=<email> ./scripts/setup-instance.sh
#
#   For native IAM users (non-federated):
#   OCIR_AUTH_TOKEN=<token> OCIR_USERNAME=<iam-username> USE_IDCS=false ./scripts/setup-instance.sh
#
# Optional overrides:
#   INSTANCE_IP   — defaults to `terraform output instance_public_ip`
#   SSH_USER      — defaults to ubuntu
#   SSH_KEY       — defaults to ~/.ssh/id_rsa

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

OCIR_AUTH_TOKEN="${OCIR_AUTH_TOKEN:?OCIR_AUTH_TOKEN must be set. Generate one in OCI Console → User Settings → Auth Tokens.}"
OCIR_USERNAME="${OCIR_USERNAME:?OCIR_USERNAME must be set (email for IDCS, IAM username for native).}"
USE_IDCS="${USE_IDCS:-true}"

if [[ -z "${INSTANCE_IP:-}" ]]; then
  echo "→ Reading instance IP from terraform output..."
  INSTANCE_IP="$(cd "$TERRAFORM_DIR" && terraform output -raw instance_public_ip)"
fi

if [[ -z "${OCIR_REGISTRY:-}" ]]; then
  OCIR_REGISTRY="$(cd "$TERRAFORM_DIR" && terraform output -raw ocir_registry)"
fi

if [[ -z "${TENANCY_NAMESPACE:-}" ]]; then
  TENANCY_NAMESPACE="$(cd "$TERRAFORM_DIR" && terraform output -raw tenancy_namespace)"
fi

SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"

if [[ "$USE_IDCS" == "true" ]]; then
  DOCKER_USERNAME="${TENANCY_NAMESPACE}/oracleidentitycloudservice/${OCIR_USERNAME}"
else
  DOCKER_USERNAME="${TENANCY_NAMESPACE}/${OCIR_USERNAME}"
fi

echo "Instance  : $SSH_USER@$INSTANCE_IP"
echo "Registry  : $OCIR_REGISTRY"
echo "Docker usr: $DOCKER_USERNAME"
echo ""
echo "→ Configuring OCIR authentication on instance (token transmitted via SSH only)..."

# Base64-encode the token to eliminate any quoting hazards in the SSH command string.
# Base64 output is alphanumeric + /+= — safe inside single quotes on the remote side.
ENCODED_TOKEN="$(printf '%s' "$OCIR_AUTH_TOKEN" | base64 | tr -d '\n')"

# The double-quoted SSH argument causes the local shell to expand $ENCODED_TOKEN,
# $OCIR_REGISTRY, and $DOCKER_USERNAME before sending the string to the remote.
# Single-quoted values protect those expansions from further interpretation by the
# remote shell. The auth token is never written to a file or a process argument.
# shellcheck disable=SC2029
ssh $SSH_OPTS "$SSH_USER@$INSTANCE_IP" "
  printf '%s' '$ENCODED_TOKEN' | base64 --decode \
    | sudo docker login '$OCIR_REGISTRY' \
        --username '$DOCKER_USERNAME' \
        --password-stdin
"

echo ""
echo "Done. The instance can now pull images from $OCIR_REGISTRY."
echo ""
echo "Next steps:"
echo "  1. Copy TLS certs to /opt/shedbooks/certs/ and /opt/shedbooks/certs/postgres/"
echo "  2. Edit /opt/shedbooks/.env and fill in all CHANGE_ME values"
echo "  3. Run: ./scripts/deploy.sh"
echo "  4. Run: ssh $SSH_USER@$INSTANCE_IP 'sudo systemctl start shedbooks'"
