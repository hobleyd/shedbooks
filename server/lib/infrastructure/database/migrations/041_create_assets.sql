-- Migration 041: Create assets table for the Asset Register.
--
-- Parameters: none
--
-- asset_no is the primary business key; (entity_id, asset_no) is UNIQUE to
-- allow reentrant UPSERT imports without creating duplicates.
-- estimated_market_value_cents stores dollar amounts × 100 (no cents in source data).
-- manufacture_year stores the integer year; NULL when unknown.
-- Soft deletes via deleted_at.

CREATE TABLE IF NOT EXISTS assets (
  id                            UUID          NOT NULL DEFAULT gen_random_uuid(),
  entity_id                     TEXT          NOT NULL,
  asset_no                      TEXT          NOT NULL,
  asset_type                    TEXT          NOT NULL,
  description                   TEXT,
  brand                         TEXT,
  identification                TEXT,
  serial_no                     TEXT,
  manufacture_year              INTEGER,
  estimated_market_value_cents  BIGINT,
  created_at                    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at                    TIMESTAMPTZ,

  CONSTRAINT assets_pkey PRIMARY KEY (id),
  CONSTRAINT assets_entity_asset_no_unique UNIQUE (entity_id, asset_no)
);

CREATE INDEX IF NOT EXISTS assets_entity_id_idx
  ON assets (entity_id)
  WHERE deleted_at IS NULL;
