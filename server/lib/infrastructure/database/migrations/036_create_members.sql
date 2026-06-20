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

-- Migration: 036_create_members
-- Stores club membership roster with CardDAV sync support.
-- Status is stored as a raw string to round-trip all known values:
--   year (e.g. "2026"), "FLM" (Full Life Member), "GN 2024", "Guest", or NULL.
--
-- Parameters: none

CREATE TABLE members (
    -- @param id                UUID primary key, auto-generated
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- @param entity_id         Organisation identifier (Auth0 org ID)
    entity_id           TEXT            NOT NULL,
    -- @param name              Full name of the member
    name                TEXT            NOT NULL,
    -- @param date_joined       Date the member first joined
    date_joined         DATE            NULL,
    -- @param membership_status Raw status string: year ("2026"), "FLM", "GN 2024", "Guest", or NULL
    membership_status   TEXT            NULL,
    -- @param street_address    Street address
    street_address      TEXT            NULL,
    -- @param po_box            PO Box
    po_box              TEXT            NULL,
    -- @param email             Email address
    email               TEXT            NULL,
    -- @param phone             Phone number(s)
    phone               TEXT            NULL,
    -- @param date_of_birth     Date of birth
    date_of_birth       DATE            NULL,
    -- @param emergency_contact Emergency contact name and/or phone
    emergency_contact   TEXT            NULL,
    -- @param etag              CardDAV ETag (regenerated on every update)
    etag                TEXT            NOT NULL DEFAULT uuid_generate_v4()::text,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    -- Null when active; set to soft-delete the record
    deleted_at          TIMESTAMPTZ     NULL
);

CREATE INDEX idx_members_entity_id ON members (entity_id)  WHERE deleted_at IS NULL;
CREATE INDEX idx_members_name      ON members (name)        WHERE deleted_at IS NULL;
CREATE INDEX idx_members_etag      ON members (etag)        WHERE deleted_at IS NULL;
