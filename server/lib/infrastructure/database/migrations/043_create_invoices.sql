-- 043_create_invoices.sql
-- @param entity_id  Tenant scoping key
-- @param contact_id FK to contacts
-- @param general_ledger_id FK to general_ledger

CREATE TABLE invoices (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id       TEXT        NOT NULL,
    invoice_number  TEXT        NOT NULL,
    invoice_date    DATE        NOT NULL,
    contact_id      UUID        NOT NULL REFERENCES contacts(id),
    total_amount_cents  INTEGER NOT NULL DEFAULT 0,
    total_gst_cents     INTEGER NOT NULL DEFAULT 0,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (entity_id, invoice_number)
);

CREATE INDEX idx_invoices_entity_id ON invoices (entity_id);

CREATE TABLE invoice_line_items (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id           TEXT        NOT NULL,
    invoice_id          UUID        NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description         TEXT        NOT NULL DEFAULT '',
    general_ledger_id   UUID        NOT NULL REFERENCES general_ledger(id),
    amount_cents        INTEGER     NOT NULL DEFAULT 0,
    gst_cents           INTEGER     NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_line_items_invoice_id ON invoice_line_items (invoice_id);
