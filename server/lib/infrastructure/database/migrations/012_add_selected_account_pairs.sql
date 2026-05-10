-- @description Adds selected_account_pairs to dashboard_preferences for paired income/expense GL account display.
-- @param entity_id TEXT - Existing primary key (not modified).

ALTER TABLE dashboard_preferences
  ADD COLUMN selected_account_pairs JSONB NOT NULL DEFAULT '[]'::jsonb;
