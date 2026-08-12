-- 047_add_address_to_contacts.sql
-- @param address Multi-line postal/billing address for the contact, used on invoices

ALTER TABLE contacts ADD COLUMN address TEXT;
