-- Add is_cash flag to transactions to distinguish cash payments from bank-reconciled transactions.
-- Defaults to FALSE so all historical records are unaffected.
ALTER TABLE transactions ADD COLUMN is_cash BOOLEAN NOT NULL DEFAULT FALSE;
