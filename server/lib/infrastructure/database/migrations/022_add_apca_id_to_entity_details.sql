-- Migration: 022_add_apca_id_to_entity_details
-- Adds the 6-digit APCA ID (User ID) to entity details for ABA file generation.

ALTER TABLE entity_details
ADD COLUMN apca_id CHAR(6);
