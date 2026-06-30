-- Migration 042: Add invoice_number_format to entity_details.
--
-- Parameters: none
--
-- Stores the format pattern used to generate sequential invoice numbers.
-- Tokens: YYYY (4-digit year), YY (2-digit year), # (sequential digit).
-- Default 'WMS-YY-###' produces numbers like WMS-26-001.

ALTER TABLE entity_details
  ADD COLUMN IF NOT EXISTS invoice_number_format TEXT NOT NULL DEFAULT 'WMS-YY-###';
