-- Migration 059: Add executed_date to capex_requests.
--
-- Parameters: none
--
-- Tracks when an approved capex request's purchase was actually carried
-- out, independent of the approve/reject decision itself (the register
-- shows approved requests sitting unexecuted for months, and in one case
-- a purchase proceeding before the paperwork caught up) — so this is a
-- free-standing nullable date, not folded into the decision fields.

ALTER TABLE capex_requests
  ADD COLUMN IF NOT EXISTS executed_date DATE;
