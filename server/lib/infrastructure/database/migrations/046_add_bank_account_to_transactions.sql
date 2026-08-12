-- 046_add_bank_account_to_transactions.sql
-- @param bank_account_id  FK to bank_accounts (nullable — set when a transaction is bank-matched
--                          during reconciliation; unmatched/legacy transactions have no value)

ALTER TABLE transactions
    ADD COLUMN bank_account_id UUID REFERENCES bank_accounts(id);
