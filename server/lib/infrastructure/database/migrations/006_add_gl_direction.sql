-- @description Adds money direction enum to general_ledger accounts.

CREATE TYPE gl_direction AS ENUM ('money_in', 'money_out');

ALTER TABLE general_ledger
  ADD COLUMN direction gl_direction NOT NULL DEFAULT 'money_in';
