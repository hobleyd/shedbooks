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

-- Migration: 067_add_payment_method_to_transactions
-- Records how a Money-Out payment is sent to the bank: 'directDebit' goes
-- in the ABA upload file, 'bpay' goes in the CommBiz BPAY upload file.
-- Values match the server's PaymentMethod enum names.
--
-- Existing non-cash Money-Out transactions whose contact is paid via BPAY
-- (contacts.is_bpay, migration 061) are backfilled to 'bpay' so they
-- land in the right upload file.

ALTER TABLE transactions
ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'directDebit'
    CONSTRAINT chk_transactions_payment_method
    CHECK (payment_method IN ('directDebit', 'bpay'));

UPDATE transactions t
SET payment_method = 'bpay'
FROM contacts c
WHERE c.id = t.contact_id
  AND c.entity_id = t.entity_id
  AND c.is_bpay
  AND t.transaction_type = 'debit'
  AND NOT t.is_cash;
