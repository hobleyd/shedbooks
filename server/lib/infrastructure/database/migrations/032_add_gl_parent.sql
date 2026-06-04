-- Add parent_id to general_ledger to model account hierarchy.
-- Top-level accounts have parent_id = NULL.
ALTER TABLE general_ledger
  ADD COLUMN parent_id UUID REFERENCES general_ledger(id) NULL;

CREATE INDEX idx_general_ledger_parent ON general_ledger(parent_id);
