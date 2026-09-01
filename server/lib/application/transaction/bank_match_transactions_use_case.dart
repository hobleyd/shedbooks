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

import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Marks a set of transactions as bank-matched.
class BankMatchTransactionsUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const BankMatchTransactionsUseCase(this._repository, this._lockedMonths);

  /// Sets [bank_matched = true] for all [ids] within [entityId], recording
  /// [bankAccountId] as the account they were reconciled against (if known).
  /// When [transactionDate] is given (the bank statement row's clearing date),
  /// it is also stamped onto the matched transactions so a later re-import can
  /// still recognise them by date + amount even if the original reference
  /// didn't match. In that case, each transaction's existing month and the
  /// target month are checked against the lock, mirroring
  /// [UpdateTransactionUseCase] — bank-match never moved a transaction's date
  /// before, so this only applies when [transactionDate] is provided.
  Future<void> execute({
    required List<String> ids,
    required String entityId,
    String? bankAccountId,
    DateTime? transactionDate,
  }) async {
    if (ids.isEmpty) return;

    if (transactionDate != null) {
      final newMonth = _monthYear(transactionDate);
      for (final id in ids) {
        final existing = await _repository.findById(id, entityId: entityId);
        if (existing == null) continue;

        final existingMonth = _monthYear(existing.transactionDate);
        if (await _lockedMonths.isLocked(entityId, existingMonth)) {
          throw MonthIsLockedException(existingMonth);
        }
        if (newMonth != existingMonth &&
            await _lockedMonths.isLocked(entityId, newMonth)) {
          throw MonthIsLockedException(newMonth);
        }
      }
    }

    await _repository.bankMatch(
      ids,
      entityId: entityId,
      bankAccountId: bankAccountId,
      transactionDate: transactionDate,
    );
  }

  static String _monthYear(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
