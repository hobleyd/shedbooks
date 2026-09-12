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

-- Migration: 057_add_o365_mailbox_to_members
-- Tracks the tenant sign-in account (Entra ID user + Exchange mailbox)
-- created for a member via the "Create O365 mailbox" admin action —
-- distinct from members.email (the member's own personal address, used
-- for GAL contact sync) and from o365_contact_id (the GAL mail contact's
-- Exchange identity). Deliberately a separate column: writing the new
-- tenant address into members.email would break GAL contact matching,
-- which is keyed on that field (see 2026-08-16-o365-member-sync.md).
--
-- Parameters: none

-- @param o365_mailbox_upn Encrypted (AES-256-GCM via FieldEncryptor). The tenant sign-in
--                          address (firstname.surname@<tenant domain>) assigned to this
--                          member, or NULL if no mailbox has been created for them.
-- @param o365_mailbox_created_at Timestamp the mailbox was created; NULL until created.
ALTER TABLE members
  ADD COLUMN o365_mailbox_upn TEXT NULL,
  ADD COLUMN o365_mailbox_created_at TIMESTAMPTZ NULL;
