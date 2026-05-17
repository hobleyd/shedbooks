-- Migration: 023_widen_contact_bank_fields
-- Widens contact bank fields to TEXT to accommodate encrypted values.

ALTER TABLE contacts ALTER COLUMN bsb TYPE TEXT;
ALTER TABLE contacts ALTER COLUMN account_number TYPE TEXT;
