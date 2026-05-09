-- Migration: 010_add_abn_to_contacts
-- Adds ABN (Australian Business Number) to contacts.
-- ABN is an 11-digit identifier; enforced at the application layer for companies.
--
-- Parameters: none

ALTER TABLE contacts
  ADD COLUMN abn CHAR(11) NULL;

-- Persons must not have an ABN.
ALTER TABLE contacts
  ADD CONSTRAINT chk_person_no_abn
    CHECK (contact_type != 'person' OR abn IS NULL);

CREATE INDEX idx_contacts_abn ON contacts (abn) WHERE deleted_at IS NULL AND abn IS NOT NULL;
