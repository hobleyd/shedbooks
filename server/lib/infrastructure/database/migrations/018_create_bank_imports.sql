-- Copyright (C) 2026 David Hobley
--
-- This file is part of Shedbooks.
--
-- Shedbooks is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Shedbooks is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
