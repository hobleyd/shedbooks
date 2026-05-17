-- @description: Tracks months that have been locked, preventing any further
--               edits to transactions whose date falls within that month.
-- @param: none

CREATE TABLE locked_months (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id  TEXT        NOT NULL,
  month_year TEXT        NOT NULL, -- YYYY-MM format
  locked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (entity_id, month_year)
);

CREATE INDEX locked_months_entity_idx ON locked_months (entity_id);
