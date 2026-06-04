-- Infer parent_id for GL accounts from label hierarchy.
-- e.g. label "4-2000-60" becomes a child of "4-2000" which is a child of "4".
-- The direct parent is the longest label that is a strict prefix (label || '-') of this account's label.
UPDATE general_ledger g
SET parent_id = (
  SELECT g2.id
  FROM general_ledger g2
  WHERE g2.entity_id = g.entity_id
    AND g2.deleted_at IS NULL
    AND g2.id != g.id
    AND g.label LIKE g2.label || '-%'
  ORDER BY length(g2.label) DESC
  LIMIT 1
)
WHERE g.deleted_at IS NULL;
