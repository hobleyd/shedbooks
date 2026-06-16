// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

import '../entities/closing_bank_balance.dart';

/// Repository contract for [ClosingBankBalance] persistence.
abstract class IClosingBankBalanceRepository {
  /// Inserts or updates the closing balance for the given bank account and date.
  ///
  /// Uses UPSERT on (entity_id, bank_account_id, balance_date) so that
  /// re-running a reconciliation for the same period updates the record.
  Future<ClosingBankBalance> save({
    required String entityId,
    required String bankAccountId,
    required String balanceDate,
    required int balanceCents,
    required String statementPeriod,
  });

  /// Returns all closing balances for [bankAccountId], ordered by date descending.
  Future<List<ClosingBankBalance>> findByBankAccount({
    required String entityId,
    required String bankAccountId,
  });

  /// Returns all closing balances for the entity, ordered by date descending.
  Future<List<ClosingBankBalance>> findAllForEntity({
    required String entityId,
  });
}
