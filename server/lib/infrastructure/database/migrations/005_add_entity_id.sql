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

-- Migration: 005_add_entity_id
-- Adds entity_id (Auth0 org_id) to all tables for multi-tenancy.
-- Existing dev rows receive an empty string so the migration runs cleanly;
-- they will never be returned to any tenant-scoped query.
--
-- Parameters: none

ALTER TABLE general_ledger ADD COLUMN entity_id VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE gst_rates      ADD COLUMN entity_id VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE contacts       ADD COLUMN entity_id VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE transactions   ADD COLUMN entity_id VARCHAR(255) NOT NULL DEFAULT '';

-- The gst_rates unique effective-date constraint must be scoped per entity.
DROP INDEX idx_gst_rates_effective_from_unique;
CREATE UNIQUE INDEX idx_gst_rates_effective_from_unique
    ON gst_rates (entity_id, effective_from)
    WHERE deleted_at IS NULL;

-- Indexes for entity-scoped lookups.
CREATE INDEX idx_general_ledger_entity_id ON general_ledger (entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_gst_rates_entity_id      ON gst_rates      (entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_contacts_entity_id       ON contacts       (entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_entity_id   ON transactions   (entity_id) WHERE deleted_at IS NULL;
