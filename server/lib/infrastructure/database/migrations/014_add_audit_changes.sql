-- Migration: 014_add_audit_changes
-- Adds a JSONB column to audit_log to store field-level change details.
--
-- For UPDATE actions: { "fieldName": { "from": oldValue, "to": newValue } }
-- For CREATE actions: flat snapshot of the new record values
-- For DELETE actions: flat snapshot of the deleted record values

ALTER TABLE audit_log ADD COLUMN changes JSONB;
