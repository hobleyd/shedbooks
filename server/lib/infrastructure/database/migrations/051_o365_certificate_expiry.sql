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

-- Migration: 051_o365_certificate_expiry
-- Tracks when the currently-saved certificate expires so the admin screen
-- can warn before Exchange Online auth starts failing. Only populated when
-- Shedbooks generates the certificate itself (see
-- GenerateO365CertificateUseCase); left NULL for certificates the admin
-- uploads directly, since Shedbooks never parses an uploaded PFX to
-- extract its expiry.
--
-- Parameters: none

-- @param certificate_expires_at Expiry of certificate_pfx, not encrypted (not sensitive). NULL for
--                                admin-uploaded certificates whose expiry Shedbooks never inspected.
ALTER TABLE o365_sync_settings ADD COLUMN certificate_expires_at TIMESTAMPTZ NULL;
