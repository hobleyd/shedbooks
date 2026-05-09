#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-folder>" >&2
  exit 1
fi

BACKUP_DIR="$1"

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

docker exec shedbooks-db-1 \
  env PGPASSWORD="$DB_PASSWORD" \
  pg_dump -U shedbooks -d shedbooks -F c \
  > "$BACKUP_FILE"

echo "Backup complete: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
