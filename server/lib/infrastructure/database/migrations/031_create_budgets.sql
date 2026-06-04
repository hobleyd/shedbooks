-- Migration: 031_create_budgets
-- Creates tables for annual budget management per GL account per calendar month.
-- Includes a GL-mapping table to persist legacy-code → current-GL matches for CSV imports.
--
-- Parameters: none

CREATE TABLE budgets (
    -- @param id          UUID primary key
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- @param entity_id   Auth0 org ID
    entity_id       TEXT        NOT NULL,
    -- @param year        Calendar year (e.g. 2025)
    year            INTEGER     NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(entity_id, year)
);

CREATE TABLE budget_lines (
    -- @param id                UUID primary key
    id                  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    -- @param budget_id         References budgets(id), cascades on delete
    budget_id           UUID    NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    -- @param general_ledger_id UUID of the GL account (no FK; GL may be deleted after budget is set)
    general_ledger_id   UUID    NOT NULL,
    -- @param month             Calendar month 1–12
    month               INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    -- @param amount_cents      Budgeted amount in cents (always non-negative)
    amount_cents        BIGINT  NOT NULL DEFAULT 0,
    UNIQUE(budget_id, general_ledger_id, month)
);

-- Persists GL code mappings from legacy systems for re-use on future CSV imports.
CREATE TABLE budget_gl_mappings (
    -- @param id                UUID primary key
    id                  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    -- @param entity_id         Auth0 org ID
    entity_id           TEXT    NOT NULL,
    -- @param external_code     Code from the external/legacy system
    external_code       TEXT    NOT NULL,
    -- @param external_name     Human-readable name from the external system
    external_name       TEXT    NOT NULL DEFAULT '',
    -- @param general_ledger_id Matching GL account in this system
    general_ledger_id   UUID    NOT NULL,
    UNIQUE(entity_id, external_code)
);

CREATE INDEX idx_budgets_entity ON budgets(entity_id);
CREATE INDEX idx_budget_lines_budget ON budget_lines(budget_id);
CREATE INDEX idx_budget_gl_mappings_entity ON budget_gl_mappings(entity_id);