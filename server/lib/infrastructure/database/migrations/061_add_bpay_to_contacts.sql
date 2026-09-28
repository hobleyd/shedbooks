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

-- Migration: 061_add_bpay_to_contacts
-- Adds BPAY as an alternative, mutually-exclusive payment method to the
-- existing BSB/account number pair. bpay_reference is widened to TEXT
-- (rather than VARCHAR) to accommodate encrypted values, matching bsb and
-- account_number (see 023_widen_contact_bank_fields).

ALTER TABLE contacts
ADD COLUMN is_bpay BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN bpay_biller_code TEXT,
ADD COLUMN bpay_reference TEXT;
