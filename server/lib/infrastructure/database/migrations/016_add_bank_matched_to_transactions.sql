-- @description Adds bank_matched flag to track whether a transaction has been
--              reconciled against a bank statement entry.
ALTER TABLE transactions
  ADD COLUMN bank_matched BOOLEAN NOT NULL DEFAULT FALSE;
