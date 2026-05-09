-- @description Creates the entity_details table for storing organisation identity information.
-- @param entity_id TEXT - The entity (tenant) identifier from Auth0 app_metadata.
-- @param name TEXT - The organisation name.
-- @param abn CHAR(11) - The 11-digit Australian Business Number.
-- @param incorporation_identifier TEXT - The incorporation or association registration number.

CREATE TABLE entity_details (
  entity_id                TEXT        PRIMARY KEY,
  name                     TEXT        NOT NULL,
  abn                      CHAR(11)    NOT NULL,
  incorporation_identifier TEXT        NOT NULL,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
