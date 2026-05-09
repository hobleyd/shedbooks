-- @description Creates the dashboard_preferences table for persisting per-entity GL account selections.
-- @param entity_id TEXT - The entity (tenant) identifier from Auth0 app_metadata.

CREATE TABLE dashboard_preferences (
  entity_id    TEXT        PRIMARY KEY,
  selected_gl_ids TEXT[]  NOT NULL DEFAULT '{}'
);
