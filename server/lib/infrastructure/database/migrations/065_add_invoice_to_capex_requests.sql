-- Migration 065: Optionally tie a capex request to an invoice raised to
-- fund it, record what was actually spent, and add the "edit decided
-- requests" action permission.
--
-- Parameters: none
--
-- @param invoice_id   The invoice this request depends on (e.g. a grant or
--                     member contribution invoiced to cover the purchase);
--                     NULL when the request has no such dependency. Invoices
--                     are hard-deleted, so the link is cleared rather than
--                     blocking the delete. Tenant scoping is enforced by the
--                     application (the invoice must share the request's
--                     entity_id) — the FK alone cannot express that.
--
-- @param actual_spent_cents   What the purchase actually cost, GST-inclusive,
--                             recorded with the executed date; NULL until
--                             known. Distinct from total_amount_cents (the
--                             amount requested) — when set, it is the "amount
--                             spent" the linked invoice is compared against.
--
-- capex-edit-decided gates editing a request after it has been approved or
-- rejected (including correcting its executed date). Seeded stricter than
-- the capex-requests page's can_write, same as capex-approve-reject in 062.

ALTER TABLE capex_requests
  ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL;

ALTER TABLE capex_requests
  ADD COLUMN IF NOT EXISTS actual_spent_cents BIGINT;

CREATE INDEX IF NOT EXISTS capex_requests_invoice_id_idx
  ON capex_requests (invoice_id)
  WHERE invoice_id IS NOT NULL;

INSERT INTO role_action_permission_defaults (action_key, role, can_perform) VALUES
  ('capex-edit-decided', 'viewer',        FALSE),
  ('capex-edit-decided', 'contributor',   FALSE),
  ('capex-edit-decided', 'administrator', TRUE)
ON CONFLICT (action_key, role) DO NOTHING;
