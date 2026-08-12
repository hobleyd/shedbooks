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

-- "Square Payment" is no longer offered as a distinct payment method on
-- Money-In transactions (it now reads "Bank Transfer" like every other
-- non-cash payment). Normalize historical rows recorded under either the
-- internal 'Square' value or the display label 'Square Payment'.
UPDATE transactions
SET receipt_number = 'Bank Transfer',
    updated_at      = NOW()
WHERE receipt_number IN ('Square', 'Square Payment');
