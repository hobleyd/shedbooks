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

-- Migration: 064_null_empty_shedbooks_app_role
-- Revoking a member's Shedbooks access cached an empty string instead of
-- NULL in members.shedbooks_app_role (manage_app_role_assignment.ps1
-- serialised a PowerShell [string] null as ''). The column's contract
-- (migration 060) is NULL for "no access", and the Members page failed to
-- render any row holding ''. Normalises the existing rows.
--
-- Parameters: none
UPDATE members
SET shedbooks_app_role = NULL
WHERE shedbooks_app_role = '';
