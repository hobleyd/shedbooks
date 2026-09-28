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

-- Migration: 060_add_shedbooks_app_role_to_members
-- Caches the Entra app role (viewer/contributor/administrator, or NULL for
-- no access) last granted to this member's O365 mailbox account via the
-- Membership screen's access-management action. This is a cache of Graph
-- state, not the source of truth: it is written from whatever
-- SetMemberAppRoleUseCase reads back from Microsoft Graph after a change
-- (self-healing on every write), but can go stale if the role is ever
-- changed directly in Entra rather than through Shedbooks.
--
-- Parameters: none

-- @param shedbooks_app_role         'viewer' | 'contributor' | 'administrator' | NULL (no access).
-- @param shedbooks_app_role_set_at  Timestamp of the last successful change; NULL until first set.
ALTER TABLE members
  ADD COLUMN shedbooks_app_role TEXT NULL,
  ADD COLUMN shedbooks_app_role_set_at TIMESTAMPTZ NULL;
