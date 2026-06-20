-- Migration 039: split members.name into first_name and last_name
--
-- Existing data uses "lastname firstname(s)" format with an optional comma
-- between the last name and first names. Both formats are handled:
--   "Smith, John"   → last_name="Smith"  first_name="John"
--   "Smith John"    → last_name="Smith"  first_name="John"
--   "Smith"         → last_name="Smith"  first_name=""

ALTER TABLE members
  ADD COLUMN last_name  TEXT NOT NULL DEFAULT '',
  ADD COLUMN first_name TEXT NOT NULL DEFAULT '';

UPDATE members SET
  last_name  = TRIM(CASE
                 WHEN name LIKE '%,%' THEN SPLIT_PART(name, ',', 1)
                 WHEN name LIKE '% %' THEN SPLIT_PART(name, ' ', 1)
                 ELSE name END),
  first_name = TRIM(CASE
                 WHEN name LIKE '%,%' THEN SUBSTR(name, STRPOS(name, ',') + 1)
                 WHEN name LIKE '% %' THEN SUBSTR(name, STRPOS(name, ' ') + 1)
                 ELSE '' END);

-- Remove the DEFAULT now that existing rows are backfilled.
ALTER TABLE members
  ALTER COLUMN last_name  DROP DEFAULT,
  ALTER COLUMN first_name DROP DEFAULT;

-- Make name nullable so we stop writing to it without losing history.
ALTER TABLE members ALTER COLUMN name DROP NOT NULL;
