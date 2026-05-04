-- Migration: 001_create_general_ledger
-- Creates the general_ledger table for chart-of-accounts entries.
--
-- Parameters: none

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE general_ledger (
    -- @param id        UUID primary key, auto-generated
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- @param label     Short display name for the account
    label           VARCHAR(255)    NOT NULL,
    -- @param description  Detailed purpose of the account
    description     TEXT            NOT NULL,
    -- @param gst_applicable  Whether GST applies to transactions on this account
    gst_applicable  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    -- Null when active; set to soft-delete the record
    deleted_at      TIMESTAMPTZ     NULL
);

CREATE INDEX idx_general_ledger_deleted_at ON general_ledger (deleted_at);
