-- Migration: 013_create_audit_log
-- Records every mutating API call and sensitive read (e.g. backup) per entity.
-- Indexed on (entity_id, created_at DESC) to support paginated tenant queries.
--
-- Parameters: none

CREATE TABLE audit_log (
    -- @param id          UUID primary key, auto-generated
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- @param entity_id   Auth0 org ID of the acting entity
    entity_id       TEXT        NOT NULL,
    -- @param user_id     Auth0 sub claim of the acting user
    user_id         TEXT        NOT NULL DEFAULT '',
    -- @param user_email  Email claim from the JWT, when present
    user_email      TEXT        NOT NULL DEFAULT '',
    -- @param ip_address  Client IP from X-Forwarded-For / X-Real-IP
    ip_address      TEXT        NOT NULL DEFAULT '',
    -- @param method      HTTP method (GET, POST, PUT, DELETE)
    method          TEXT        NOT NULL,
    -- @param path        Full request path (e.g. /contacts/uuid)
    path            TEXT        NOT NULL,
    -- @param action      Semantic action: CREATE, UPDATE, DELETE, MERGE, BACKUP, RESTORE
    action          TEXT        NOT NULL,
    -- @param table_name  Affected logical table (e.g. contacts, general_ledger)
    table_name      TEXT        NOT NULL,
    -- @param record_id   ID of the affected record when identifiable; null otherwise
    record_id       TEXT,
    -- @param status_code HTTP response status code
    status_code     INTEGER     NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_entity_created ON audit_log (entity_id, created_at DESC);
