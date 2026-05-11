-- @description Adds configurable receipt format patterns for money-in and money-out
--              transactions. Empty string means no format is enforced.
ALTER TABLE entity_details
  ADD COLUMN money_in_receipt_format  TEXT NOT NULL DEFAULT '',
  ADD COLUMN money_out_receipt_format TEXT NOT NULL DEFAULT '';
