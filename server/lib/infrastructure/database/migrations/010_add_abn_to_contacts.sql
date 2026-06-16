-- Copyright (C) 2026 David Hobley
--
-- This file is part of Shedbooks.
--
-- Shedbooks is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Shedbooks is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
