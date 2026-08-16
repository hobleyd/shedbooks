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

-- Migration: 050_o365_gal_contacts
-- Switches O365 member sync from writing to one mailbox's personal Contacts
-- folder (Graph API, client-secret auth) to creating organization-wide mail
-- contacts visible in the Global Address List for every user (Exchange
-- Online PowerShell, certificate-based app-only auth). Graph has no
-- supported write path for org-wide contacts in a cloud-only tenant, so
-- this requires a certificate instead of a client secret, and there is no
-- longer a single "target mailbox" to write into.
--
-- Parameters: none

ALTER TABLE o365_sync_settings DROP COLUMN client_secret;
ALTER TABLE o365_sync_settings DROP COLUMN target_mailbox;

-- @param certificate_pfx      Base64-encoded PKCS#12 certificate (public + private key), encrypted at
--                             rest; used for Exchange Online app-only auth (Connect-ExchangeOnline
--                             -CertificateFilePath). Never returned to clients.
ALTER TABLE o365_sync_settings ADD COLUMN certificate_pfx TEXT NOT NULL DEFAULT '';
-- @param certificate_password Password protecting certificate_pfx, encrypted at rest. Never returned
--                              to clients.
ALTER TABLE o365_sync_settings ADD COLUMN certificate_password TEXT NOT NULL DEFAULT '';

ALTER TABLE o365_sync_settings ALTER COLUMN certificate_pfx DROP DEFAULT;
ALTER TABLE o365_sync_settings ALTER COLUMN certificate_password DROP DEFAULT;

-- members.o365_contact_id now stores the mail contact's Exchange .Identity
-- string (NOT ExternalDirectoryObjectId, which is populated asynchronously
-- by directory sync and may be unavailable immediately after creation)
-- rather than a Microsoft Graph contact id. The column and its "pending
-- sync" semantics (see 049_create_o365_sync.sql) are unchanged, only what
-- the id identifies has changed.
