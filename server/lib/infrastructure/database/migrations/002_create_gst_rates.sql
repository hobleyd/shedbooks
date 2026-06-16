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

-- Migration: 002_create_gst_rates
-- Stores GST rates with the date from which each rate applies.
-- The effective rate at any point in time is the row with the highest
-- effective_from that is on or before that date.
--
-- Parameters: none

CREATE TABLE gst_rates (
    -- @param id             UUID primary key, auto-generated
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- @param rate           Decimal fraction, e.g. 0.1000 = 10%
    rate            NUMERIC(5, 4)   NOT NULL CHECK (rate >= 0 AND rate <= 1),
    -- @param effective_from The date from which this rate applies
    effective_from  DATE            NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    -- Null when active; set to soft-delete the record
    deleted_at      TIMESTAMPTZ     NULL
);

-- Only one rate may be active per effective date.
CREATE UNIQUE INDEX idx_gst_rates_effective_from_unique
    ON gst_rates (effective_from)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_gst_rates_deleted_at ON gst_rates (deleted_at);
