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

-- Migration: 014_add_audit_changes
-- Adds a JSONB column to audit_log to store field-level change details.
--
-- For UPDATE actions: { "fieldName": { "from": oldValue, "to": newValue } }
-- For CREATE actions: flat snapshot of the new record values
-- For DELETE actions: flat snapshot of the deleted record values

ALTER TABLE audit_log ADD COLUMN changes JSONB;
