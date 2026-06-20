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

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <backup-folder>" >&2
  exit 1
fi

CONTAINER="$1"
BACKUP_DIR="$2"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Error: '$BACKUP_DIR' is not a directory." >&2
  exit 1
fi

# Load DB_PASSWORD from .env if not already set.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
if [[ -z "${DB_PASSWORD:-}" && -f "$ENV_FILE" ]]; then
  DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)"
fi

if [[ -z "${DB_PASSWORD:-}" ]]; then
  echo "Error: DB_PASSWORD is not set and could not be read from .env." >&2
  exit 1
fi

TIMESTAMP="$(date +%Y-%m-%d-%H-%M)"
BACKUP_FILE="$BACKUP_DIR/shedbooks-$TIMESTAMP.bak"

echo "Backing up database to $BACKUP_FILE ..."

docker exec $CONTAINER \
  env PGPASSWORD="$DB_PASSWORD" \
  pg_dump -U shedbooks -d shedbooks -F c \
  > "$BACKUP_FILE"

echo "Backup complete: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
