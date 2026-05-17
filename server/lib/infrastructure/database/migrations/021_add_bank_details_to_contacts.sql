-- Migration: 021_add_bank_details_to_contacts
-- Adds BSB and account number fields to contacts for ABA file generation.

ALTER TABLE contacts
ADD COLUMN bsb CHAR(6),
ADD COLUMN account_number VARCHAR(10);
