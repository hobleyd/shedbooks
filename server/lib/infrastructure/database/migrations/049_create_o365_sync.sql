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

-- Migration: 049_create_o365_sync
-- Adds per-entity Microsoft 365 / Graph API app-registration settings and
-- the columns needed to track which members have been pushed to O365 as
-- Outlook contacts.
--
-- Parameters: none

CREATE TABLE o365_sync_settings (
    -- @param entity_id                 Organisation identifier (Auth0 org ID), one settings row per entity
    entity_id                   TEXT            PRIMARY KEY,
    -- @param tenant_id                 Tenant's default domain (<tenant>.onmicrosoft.com), NOT the
    --                                   Tenant ID GUID — Exchange Online's certificate-based auth
    --                                   requires the domain and rejects a GUID here
    tenant_id                   TEXT            NOT NULL,
    -- @param client_id                 Azure AD application (client) ID (GUID)
    client_id                   TEXT            NOT NULL,
    -- @param client_secret             Client credentials secret, encrypted at rest; never returned to clients
    client_secret               TEXT            NOT NULL,
    -- @param target_mailbox            Mailbox (UPN/email) whose Contacts folder members are synced into
    target_mailbox              TEXT            NOT NULL,
    -- @param initial_sync_completed_at Set the first time the manual "sync to O365" run is triggered —
    --                                  auto-sync-on-write is disabled until this is non-null
    initial_sync_completed_at   TIMESTAMPTZ     NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- @param members.o365_contact_id  Microsoft Graph contact id once the member has been pushed to O365
ALTER TABLE members ADD COLUMN o365_contact_id TEXT NULL;
-- @param members.o365_synced_at   Timestamp of the last successful push to O365; a member is "pending"
--                                 sync when this is NULL or older than the member's updated_at
ALTER TABLE members ADD COLUMN o365_synced_at TIMESTAMPTZ NULL;
