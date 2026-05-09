#!/usr/bin/env bash
set -euo pipefail

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

PSQL="docker exec -i shedbooks-db-1 env PGPASSWORD=$DB_PASSWORD psql -U shedbooks -d shedbooks -t -A"

echo "Checking for duplicate transactions..."

COUNT=$($PSQL <<'SQL'
SELECT COUNT(*) FROM (
  SELECT id
  FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY entity_id, contact_id, general_ledger_id,
                          transaction_type, receipt_number, transaction_date
             ORDER BY created_at ASC
           ) AS rn
    FROM transactions
    WHERE deleted_at IS NULL
  ) ranked
  WHERE rn > 1
) dupes;
SQL
)

if [[ "$COUNT" -eq 0 ]]; then
  echo "No duplicate transactions found."
  exit 0
fi

echo "Found $COUNT duplicate transaction(s) to remove (earliest row per group will be kept)."
echo ""
read -r -p "Proceed with soft-delete? [y/N] " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

$PSQL <<'SQL'
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY entity_id, contact_id, general_ledger_id,
                        transaction_type, receipt_number, transaction_date
           ORDER BY created_at ASC
         ) AS rn
  FROM transactions
  WHERE deleted_at IS NULL
)
UPDATE transactions
SET deleted_at = NOW(), updated_at = NOW()
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
SQL

echo "Done. $COUNT duplicate row(s) soft-deleted."
