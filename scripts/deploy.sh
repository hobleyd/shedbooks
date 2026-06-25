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

# Deploy the latest images to the OCI instance.
# Copies docker-compose.prod.yml, pulls the new images, and restarts the stack.
#
# Usage:
#   ./scripts/deploy.sh
#   INSTANCE_IP=1.2.3.4 SSH_KEY=~/.ssh/my_key ./scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Resolve instance IP from terraform output or environment
if [[ -z "${INSTANCE_IP:-}" ]]; then
  echo "→ Reading instance IP from terraform output..."
  INSTANCE_IP="$(cd "$TERRAFORM_DIR" && tofu output -raw instance_public_ip)"
fi

SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

echo "Deploying to $SSH_USER@$INSTANCE_IP"
echo ""

# Copy the production compose file
echo "→ Copying docker-compose.prod.yml..."
scp $SSH_OPTS \
  "$PROJECT_ROOT/docker-compose.prod.yml" \
  "$SSH_USER@$INSTANCE_IP:/tmp/docker-compose.prod.yml"

ssh $SSH_OPTS "$SSH_USER@$INSTANCE_IP" \
  "sudo mv /tmp/docker-compose.prod.yml /opt/shedbooks/docker-compose.prod.yml"

# Pull latest images and do a rolling restart
echo "→ Pulling images and restarting stack..."
# shellcheck disable=SC2029
ssh $SSH_OPTS "$SSH_USER@$INSTANCE_IP" "
  cd /opt/shedbooks
  sudo docker compose --env-file .env -f docker-compose.prod.yml pull
  sudo docker compose --env-file .env -f docker-compose.prod.yml up -d
"

echo ""
echo "Done. Check status with:"
echo "  ssh $SSH_USER@$INSTANCE_IP 'sudo docker compose -f /opt/shedbooks/docker-compose.prod.yml ps'"
