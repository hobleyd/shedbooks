-- Migration: 066_create_member_equipment_training
-- Records which pieces of Asset-register equipment (Wood Shop / Metal Shop
-- sections) each member has been trained on, and the date that training was
-- recorded. Replaces the single per-shop induction dates on the Membership
-- screen (members.woodworking_induction / metalworking_induction, migration
-- 037) — those columns are left in place because CardDAV, member import and
-- backup/restore still carry them.
--
-- One active row per (member, asset). Un-ticking an item soft-deletes its
-- row; ticking it again later inserts a fresh row with the new date, hence
-- the partial (deleted_at IS NULL) unique index rather than a constraint.
--
-- Parameters: none

-- @param entity_id   Organisation (entity) identifier; every query is scoped by it.
-- @param member_id   The trained member (members.id).
-- @param asset_id    The equipment trained on (assets.id).
-- @param trained_on  Date the training was recorded (the day the tick was saved).
CREATE TABLE IF NOT EXISTS member_equipment_training (
  id          UUID          NOT NULL DEFAULT gen_random_uuid(),
  entity_id   TEXT          NOT NULL,
  member_id   UUID          NOT NULL,
  asset_id    UUID          NOT NULL,
  trained_on  DATE          NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ,

  CONSTRAINT member_equipment_training_pkey PRIMARY KEY (id),
  CONSTRAINT member_equipment_training_member_fk
    FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE,
  CONSTRAINT member_equipment_training_asset_fk
    FOREIGN KEY (asset_id) REFERENCES assets (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS member_equipment_training_active_unique
  ON member_equipment_training (entity_id, member_id, asset_id)
  WHERE deleted_at IS NULL;
