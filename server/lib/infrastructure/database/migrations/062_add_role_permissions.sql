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

-- Migration: 062_add_role_permissions
-- Replaces the hardcoded three-tier role checks (role_guard.dart's
-- requireContributor/requireAdministrator, plus the client's mirrored
-- hardcoded path lists) with a database-backed, per-entity-overridable
-- permission matrix, surfaced through the new Roles admin page.
--
-- Two independent layers, not a copy-on-create snapshot:
--   - role_page_permission_defaults / role_action_permission_defaults are
--     global (not entity-scoped) and ARE "the default" a brand-new entity
--     sees automatically, since it starts with zero rows anywhere else.
--   - entity_page_permission_overrides / entity_action_permission_overrides
--     hold a row only for a cell a specific entity has explicitly changed.
-- Resolution order: entity override, else global default, else deny.
-- Action permissions add one more fallback below the entity/global action
-- rows: the action's own page's write permission (the "inherits from the
-- page" behaviour) — so role_action_permission_defaults only needs rows for
-- the handful of actions that are deliberately stricter than their page.
--
-- Only the "template entity" (see is_template_entity below) may write to
-- the global *_defaults tables; every other entity's Roles-page save can
-- only write its own entity_*_overrides rows. This is what makes "my
-- choice becomes the default for future entities, but not in reverse" a
-- structural guarantee rather than a policy someone could get wrong later.
--
-- Seed data below replicates the CURRENT hardcoded behaviour (router.dart's
-- requireContributor/requireAdministrator guards, cross-checked against
-- app_router.dart's client-side redirect rules) exactly, so enabling this
-- system is behaviour-neutral until someone visits the new Roles page.

-- @param page_key   Stable identifier matching PermissionPage.key (server) /
--                    the client's mirrored const registry. Free text, not FK'd
--                    to any other table (see entity_id convention below).
-- @param role       'viewer' | 'contributor' | 'administrator'.
CREATE TABLE role_page_permission_defaults (
  page_key  TEXT NOT NULL,
  role      TEXT NOT NULL,
  can_read  BOOLEAN NOT NULL,
  can_write BOOLEAN NOT NULL,
  PRIMARY KEY (page_key, role)
);

-- @param action_key   Stable identifier matching PermissionAction.key.
--                      Only present here when this action is deliberately
--                      stricter (or looser) than its parent page's can_write
--                      for that role — everything else simply inherits.
CREATE TABLE role_action_permission_defaults (
  action_key  TEXT NOT NULL,
  role        TEXT NOT NULL,
  can_perform BOOLEAN NOT NULL,
  PRIMARY KEY (action_key, role)
);

-- @param entity_id   Tenant identifier, same convention as every other
--                     entity-scoped table in this schema (plain TEXT column,
--                     not declared as a foreign key to entity_details).
CREATE TABLE entity_page_permission_overrides (
  entity_id TEXT NOT NULL,
  page_key  TEXT NOT NULL,
  role      TEXT NOT NULL,
  can_read  BOOLEAN NOT NULL,
  can_write BOOLEAN NOT NULL,
  PRIMARY KEY (entity_id, page_key, role)
);

CREATE TABLE entity_action_permission_overrides (
  entity_id   TEXT NOT NULL,
  action_key  TEXT NOT NULL,
  role        TEXT NOT NULL,
  can_perform BOOLEAN NOT NULL,
  PRIMARY KEY (entity_id, action_key, role)
);

-- @param is_template_entity   Marks the single entity whose Roles-page saves
--                              write to the global defaults tables above,
--                              instead of to its own entity_*_overrides rows.
--                              Exactly one entity should carry TRUE at a time.
ALTER TABLE entity_details ADD COLUMN is_template_entity BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE entity_details SET is_template_entity = TRUE
  WHERE entity_id = (SELECT entity_id FROM entity_details ORDER BY created_at ASC LIMIT 1);

-- Seed global page defaults, replicating current hardcoded behaviour.
INSERT INTO role_page_permission_defaults (page_key, role, can_read, can_write) VALUES
  ('dashboard',                    'viewer',        TRUE,  FALSE),
  ('dashboard',                    'contributor',   TRUE,  TRUE),
  ('dashboard',                    'administrator', TRUE,  TRUE),

  ('transactions',                 'viewer',        TRUE,  FALSE),
  ('transactions',                 'contributor',   TRUE,  TRUE),
  ('transactions',                 'administrator', TRUE,  TRUE),

  ('bank-reconciliation',          'viewer',        FALSE, FALSE),
  ('bank-reconciliation',          'contributor',   FALSE, FALSE),
  ('bank-reconciliation',          'administrator', TRUE,  TRUE),

  ('invoices',                     'viewer',        TRUE,  FALSE),
  ('invoices',                     'contributor',   TRUE,  TRUE),
  ('invoices',                     'administrator', TRUE,  TRUE),

  ('members',                      'viewer',        TRUE,  FALSE),
  ('members',                      'contributor',   TRUE,  TRUE),
  ('members',                      'administrator', TRUE,  TRUE),

  ('assets',                       'viewer',        TRUE,  FALSE),
  ('assets',                       'contributor',   TRUE,  TRUE),
  ('assets',                       'administrator', TRUE,  TRUE),

  ('capex-requests',               'viewer',        TRUE,  FALSE),
  ('capex-requests',               'contributor',   TRUE,  TRUE),
  ('capex-requests',               'administrator', TRUE,  TRUE),

  ('reports-assets',               'viewer',        TRUE,  FALSE),
  ('reports-assets',               'contributor',   TRUE,  FALSE),
  ('reports-assets',               'administrator', TRUE,  FALSE),

  ('reports-bas',                  'viewer',        TRUE,  FALSE),
  ('reports-bas',                  'contributor',   TRUE,  FALSE),
  ('reports-bas',                  'administrator', TRUE,  FALSE),

  ('reports-pl',                   'viewer',        TRUE,  FALSE),
  ('reports-pl',                   'contributor',   TRUE,  FALSE),
  ('reports-pl',                   'administrator', TRUE,  FALSE),

  ('reports-budget',               'viewer',        TRUE,  FALSE),
  ('reports-budget',               'contributor',   TRUE,  FALSE),
  ('reports-budget',               'administrator', TRUE,  TRUE),

  ('reports-monthly',              'viewer',        FALSE, FALSE),
  ('reports-monthly',              'contributor',   FALSE, FALSE),
  ('reports-monthly',              'administrator', TRUE,  TRUE),

  ('reports-financial-performance','viewer',        TRUE,  FALSE),
  ('reports-financial-performance','contributor',   TRUE,  FALSE),
  ('reports-financial-performance','administrator', TRUE,  FALSE),

  ('admin-entity',                 'viewer',        FALSE, FALSE),
  ('admin-entity',                 'contributor',   TRUE,  TRUE),
  ('admin-entity',                 'administrator', TRUE,  TRUE),

  ('admin-bank-accounts',          'viewer',        FALSE, FALSE),
  ('admin-bank-accounts',          'contributor',   FALSE, FALSE),
  ('admin-bank-accounts',          'administrator', TRUE,  TRUE),

  ('admin-contacts',               'viewer',        FALSE, FALSE),
  ('admin-contacts',               'contributor',   TRUE,  TRUE),
  ('admin-contacts',               'administrator', TRUE,  TRUE),

  ('admin-general-ledger',         'viewer',        FALSE, FALSE),
  ('admin-general-ledger',         'contributor',   TRUE,  TRUE),
  ('admin-general-ledger',         'administrator', TRUE,  TRUE),

  ('admin-gst-management',         'viewer',        FALSE, FALSE),
  ('admin-gst-management',         'contributor',   FALSE, FALSE),
  ('admin-gst-management',         'administrator', TRUE,  TRUE),

  ('admin-audit-log',              'viewer',        FALSE, FALSE),
  ('admin-audit-log',              'contributor',   FALSE, FALSE),
  ('admin-audit-log',              'administrator', TRUE,  FALSE),

  ('admin-backup',                 'viewer',        FALSE, FALSE),
  ('admin-backup',                 'contributor',   FALSE, FALSE),
  ('admin-backup',                 'administrator', TRUE,  TRUE),

  ('admin-locked-months',          'viewer',        FALSE, FALSE),
  ('admin-locked-months',          'contributor',   FALSE, FALSE),
  ('admin-locked-months',          'administrator', TRUE,  TRUE),

  ('admin-users',                  'viewer',        FALSE, FALSE),
  ('admin-users',                  'contributor',   FALSE, FALSE),
  ('admin-users',                  'administrator', TRUE,  TRUE),

  ('admin-o365-sync',              'viewer',        FALSE, FALSE),
  ('admin-o365-sync',              'contributor',   FALSE, FALSE),
  ('admin-o365-sync',              'administrator', TRUE,  TRUE),

  ('admin-roles',                  'viewer',        FALSE, FALSE),
  ('admin-roles',                  'contributor',   FALSE, FALSE),
  ('admin-roles',                  'administrator', TRUE,  TRUE);

-- Seed global action defaults — only the buttons that are stricter than
-- their page's can_write above. Every other action button has no row here
-- and simply inherits its page's can_write.
INSERT INTO role_action_permission_defaults (action_key, role, can_perform) VALUES
  ('transactions-import',           'viewer',        FALSE),
  ('transactions-import',           'contributor',   FALSE),
  ('transactions-import',           'administrator', TRUE),

  ('transactions-bank-upload',      'viewer',        FALSE),
  ('transactions-bank-upload',      'contributor',   FALSE),
  ('transactions-bank-upload',      'administrator', TRUE),

  ('invoices-manage-unpaid',        'viewer',        FALSE),
  ('invoices-manage-unpaid',        'contributor',   FALSE),
  ('invoices-manage-unpaid',        'administrator', TRUE),

  ('members-sync-o365',             'viewer',        FALSE),
  ('members-sync-o365',             'contributor',   FALSE),
  ('members-sync-o365',             'administrator', TRUE),

  ('members-create-mailbox',        'viewer',        FALSE),
  ('members-create-mailbox',        'contributor',   FALSE),
  ('members-create-mailbox',        'administrator', TRUE),

  ('members-set-role',              'viewer',        FALSE),
  ('members-set-role',              'contributor',   FALSE),
  ('members-set-role',              'administrator', TRUE),

  ('capex-approve-reject',          'viewer',        FALSE),
  ('capex-approve-reject',          'contributor',   FALSE),
  ('capex-approve-reject',          'administrator', TRUE),

  ('contacts-reveal-bank-details',  'viewer',        FALSE),
  ('contacts-reveal-bank-details',  'contributor',   FALSE),
  ('contacts-reveal-bank-details',  'administrator', TRUE),

  ('contacts-toggle-payment-method','viewer',        FALSE),
  ('contacts-toggle-payment-method','contributor',   FALSE),
  ('contacts-toggle-payment-method','administrator', TRUE);
