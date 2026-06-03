-- Add sort_order column to bank_accounts for user-defined display ordering.
-- @param none
ALTER TABLE bank_accounts
  ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;

-- Seed existing rows with their current alphabetical position per entity
-- so the initial order matches what users already see.
UPDATE bank_accounts
SET sort_order = sub.rn - 1
FROM (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY entity_id
           ORDER BY bank_name ASC, account_name ASC
         ) AS rn
  FROM bank_accounts
) sub
WHERE bank_accounts.id = sub.id;
