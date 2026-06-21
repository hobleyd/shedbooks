-- Add separate columns for emergency contact name and phone number.
-- The existing emergency_contact column is preserved so the data-migration script
-- (server/bin/split_emergency_contacts.dart) can decrypt, split, and populate the
-- new columns.  The old column can be dropped in a future migration once all
-- deployments have been migrated.
--
-- @param: none
ALTER TABLE members
  ADD COLUMN IF NOT EXISTS emergency_contact_name  TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT;
