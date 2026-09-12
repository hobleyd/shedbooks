-- Migration 058: Create capex_requests table for the Capital Expenditure
-- Request register.
--
-- Parameters: none
--
-- Mirrors the club's paper "Capital Expenditure Request" form: an Asset
-- Details section (what/why/alternatives) and an Expenditure Details
-- section (purchase cost, ongoing costs, other costs, total, quote count).
-- All *_cents amounts on the form are GST-inclusive (no GST split).
-- request_no is the human-readable business key (e.g. "CER 26-012");
-- (entity_id, request_no) is UNIQUE to catch numbering races.
-- status is a single pending/approved/rejected decision, matching the
-- form's one "Signed / Date" line — soft deletes via deleted_at.

CREATE TABLE IF NOT EXISTS capex_requests (
  id                        UUID          NOT NULL DEFAULT gen_random_uuid(),
  entity_id                 TEXT          NOT NULL,
  request_no                TEXT          NOT NULL,
  request_date              DATE          NOT NULL,
  prepared_by_name          TEXT          NOT NULL,
  description               TEXT          NOT NULL,
  what_is_requested         TEXT          NOT NULL,
  need_or_benefit           TEXT          NOT NULL,
  alternatives_considered   TEXT,
  purchase_cost_cents       BIGINT        NOT NULL DEFAULT 0,
  ongoing_costs_cents       BIGINT,
  other_costs_cents         BIGINT,
  cost_notes                TEXT,
  total_amount_cents        BIGINT        NOT NULL DEFAULT 0,
  quotes_received_count     INTEGER,
  status                    TEXT          NOT NULL DEFAULT 'pending',
  decision_by_name          TEXT,
  decision_at               TIMESTAMPTZ,
  decision_notes            TEXT,
  created_at                TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at                TIMESTAMPTZ,

  CONSTRAINT capex_requests_pkey PRIMARY KEY (id),
  CONSTRAINT capex_requests_entity_request_no_unique UNIQUE (entity_id, request_no),
  CONSTRAINT capex_requests_status_check CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS capex_requests_entity_id_idx
  ON capex_requests (entity_id)
  WHERE deleted_at IS NULL;
