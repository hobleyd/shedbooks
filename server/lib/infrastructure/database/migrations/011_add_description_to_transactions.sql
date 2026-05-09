-- Migration 011: add optional description to transactions
-- Parameters:
--   (none)

ALTER TABLE transactions
  ADD COLUMN description TEXT NOT NULL DEFAULT '';
