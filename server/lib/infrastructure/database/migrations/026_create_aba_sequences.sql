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

-- aba_sequences: tracks daily ABA file generation count per entity.
-- Used to produce a unique 3-digit suffix for each ABA file generated on the same day.
-- @entity_id the Auth0 organisation ID owning the sequence
-- @sequence_date the calendar date the sequence applies to
-- @sequence_number number of ABA files generated for this entity on sequence_date
CREATE TABLE aba_sequences (
  entity_id      TEXT    NOT NULL,
  sequence_date  DATE    NOT NULL,
  sequence_number INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (entity_id, sequence_date)
);
