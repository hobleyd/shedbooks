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
