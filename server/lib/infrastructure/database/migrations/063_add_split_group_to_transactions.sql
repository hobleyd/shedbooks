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

-- Migration: 063_add_split_group_to_transactions
-- Lets one payment be coded to several general ledger accounts. A split is
-- stored as one ordinary transactions row per GL line so every report that
-- groups rows by general_ledger_id keeps working unchanged. The rows of one
-- split share contact, date, receipt number, payment reference, bank account
-- and cash flag, and are tied together by split_group_id.
--
-- @param split_group_id  UUID shared by every row of one split. NULL for an
--                        ordinary single-GL transaction
-- @param split_line_no   1-based position of the row within its split, used
--                        to show the lines in the order they were entered.
--                        NULL for an ordinary single-GL transaction

ALTER TABLE transactions ADD COLUMN split_group_id UUID;
ALTER TABLE transactions ADD COLUMN split_line_no INTEGER;

CREATE INDEX idx_transactions_split_group_id
    ON transactions (split_group_id)
    WHERE split_group_id IS NOT NULL AND deleted_at IS NULL;
