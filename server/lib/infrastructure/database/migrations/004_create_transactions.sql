-- Migration: 004_create_transactions
-- Records financial transactions coded to a contact and a general ledger account.
-- Amounts are stored in cents as integers to avoid floating-point rounding errors.
--
-- Parameters: none

CREATE TYPE transaction_type AS ENUM ('debit', 'credit');

CREATE TABLE transactions (
    -- @param id                 UUID primary key, auto-generated
    id                  UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- @param contact_id         FK to contacts.id
    contact_id          UUID                NOT NULL,
    -- @param general_ledger_id  FK to general_ledger.id
    general_ledger_id   UUID                NOT NULL,
    -- @param amount             Transaction value in cents, must be > 0
    amount              INTEGER             NOT NULL,
    -- @param gst_amount         GST component in cents, 0 when not applicable
    gst_amount          INTEGER             NOT NULL DEFAULT 0,
    -- @param transaction_type   Whether this is a debit or credit
    transaction_type    transaction_type    NOT NULL,
    -- @param receipt_number     External document reference for tracking
    receipt_number      VARCHAR(100)        NOT NULL,
    -- @param transaction_date   The date the transaction occurred
    transaction_date    DATE                NOT NULL,
    created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    -- Null when active; set to soft-delete the record
    deleted_at          TIMESTAMPTZ         NULL,

    CONSTRAINT fk_transactions_contact
        FOREIGN KEY (contact_id)        REFERENCES contacts(id),
    CONSTRAINT fk_transactions_general_ledger
        FOREIGN KEY (general_ledger_id) REFERENCES general_ledger(id),

    CONSTRAINT chk_transactions_amount_positive
        CHECK (amount > 0),
    CONSTRAINT chk_transactions_gst_amount_non_negative
        CHECK (gst_amount >= 0),
    CONSTRAINT chk_transactions_gst_not_exceeds_amount
        CHECK (gst_amount <= amount)
);

CREATE INDEX idx_transactions_contact_id        ON transactions (contact_id)        WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_general_ledger_id ON transactions (general_ledger_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_transaction_date  ON transactions (transaction_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_receipt_number    ON transactions (receipt_number)    WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_deleted_at        ON transactions (deleted_at);
