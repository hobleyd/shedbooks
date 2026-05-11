-- @description: Records each bank statement row that has been actioned during
--               a CBA import, so re-importing the same CSV skips already-processed rows.
-- @param: none

CREATE TABLE bank_imports (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   TEXT         NOT NULL,
  process_date DATE        NOT NULL,
  description TEXT         NOT NULL,
  amount_cents INTEGER     NOT NULL,
  is_debit    BOOLEAN      NOT NULL,
  imported_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  -- Prevents duplicate rows for the same bank statement line.
  UNIQUE (entity_id, process_date, description, amount_cents, is_debit)
);

CREATE INDEX bank_imports_entity_date_idx
  ON bank_imports (entity_id, process_date);
