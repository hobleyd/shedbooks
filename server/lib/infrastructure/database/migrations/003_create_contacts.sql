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

-- Migration: 003_create_contacts
-- Stores contacts (persons and companies) with GST registration status.
--
-- Parameters: none

CREATE TYPE contact_type AS ENUM ('person', 'company');

CREATE TABLE contacts (
    -- @param id              UUID primary key, auto-generated
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- @param name            Display name of the contact
    name            VARCHAR(500)    NOT NULL,
    -- @param contact_type    Whether the contact is a person or a company
    contact_type    contact_type    NOT NULL,
    -- @param gst_registered  Whether the contact holds a GST registration
    gst_registered  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    -- Null when active; set to soft-delete the record
    deleted_at      TIMESTAMPTZ     NULL,

    -- Persons can never be GST registered (defence-in-depth; enforced in app layer too)
    CONSTRAINT chk_person_not_gst_registered
        CHECK (contact_type != 'person' OR gst_registered = FALSE)
);

CREATE INDEX idx_contacts_deleted_at  ON contacts (deleted_at);
CREATE INDEX idx_contacts_name        ON contacts (name) WHERE deleted_at IS NULL;
CREATE INDEX idx_contacts_type        ON contacts (contact_type) WHERE deleted_at IS NULL;
