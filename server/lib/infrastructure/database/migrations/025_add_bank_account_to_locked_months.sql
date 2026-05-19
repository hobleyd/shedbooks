-- @description: Adds bank_account_id to locked_months so each bank account's
--               period can be locked independently. Existing locks are removed
--               because they cannot be associated with a specific bank account.
-- @param: none

DELETE FROM locked_months;

ALTER TABLE locked_months
  ADD COLUMN bank_account_id UUID NOT NULL;

ALTER TABLE locked_months
  DROP CONSTRAINT locked_months_entity_id_month_year_key;

ALTER TABLE locked_months
  ADD CONSTRAINT locked_months_entity_account_month_unique
    UNIQUE (entity_id, bank_account_id, month_year);

ALTER TABLE locked_months
  ADD CONSTRAINT fk_locked_months_bank_account
    FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id) ON DELETE CASCADE;

CREATE INDEX locked_months_bank_account_idx ON locked_months (bank_account_id);
