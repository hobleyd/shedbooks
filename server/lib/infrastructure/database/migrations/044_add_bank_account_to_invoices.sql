-- 044_add_bank_account_to_invoices.sql
-- @param bank_account_id  FK to bank_accounts (nullable — invoices created before this migration have no value)

ALTER TABLE invoices
    ADD COLUMN bank_account_id UUID REFERENCES bank_accounts(id);
