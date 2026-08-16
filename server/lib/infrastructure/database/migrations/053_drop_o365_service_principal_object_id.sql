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

-- Migration: 053_drop_o365_service_principal_object_id
-- Reverts 052: the O365 setup script now derives the Enterprise
-- Application (service principal) Object ID itself via Microsoft Graph
-- (Get-MgServicePrincipal -Filter "appId eq '...'"), so the admin never
-- needs to supply or store it.
--
-- Parameters: none

ALTER TABLE o365_sync_settings DROP COLUMN IF EXISTS service_principal_object_id;
