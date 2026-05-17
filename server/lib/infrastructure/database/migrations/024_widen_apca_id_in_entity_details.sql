-- Migration: 024_widen_apca_id_in_entity_details
-- Widens apca_id column to TEXT to accommodate encrypted values.

ALTER TABLE entity_details ALTER COLUMN apca_id TYPE TEXT;
