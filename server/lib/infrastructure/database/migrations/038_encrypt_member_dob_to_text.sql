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

-- Migration: 038_encrypt_member_dob_to_text
-- Changes date_of_birth from DATE to TEXT so the application layer can store
-- an AES-256-GCM encrypted ISO-8601 date string (e.g. "enc:<base64>").
-- Existing DATE values are converted to 'YYYY-MM-DD' text via to_char so that
-- the application's legacy-plaintext fallback in FieldEncryptor.decrypt() can
-- read and re-encrypt them on the next write.
--
-- Parameters: none

ALTER TABLE members
    ALTER COLUMN date_of_birth TYPE TEXT
    USING to_char(date_of_birth, 'YYYY-MM-DD');
