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

import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_line.dart';
import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// Creates a split transaction — one payment coded to several general
/// ledger accounts, stored as one transaction row per line.
class CreateSplitTransactionUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const CreateSplitTransactionUseCase(this._repository, this._lockedMonths);

  /// Validates [lines] (at least two, each with a positive amount and a GST
  /// amount no larger than it), checks the month is not locked, then persists
  /// every line atomically. Returns the persisted rows in line order.
  Future<List<Transaction>> execute({
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    bool isCash = false,
    String? bankAccountId,
    required List<TransactionLine> lines,
  }) async {
    TransactionValidator.validateLines(
      lines: lines,
      receiptNumber: receiptNumber,
      minLines: 2,
    );

    final monthYear = _monthYear(transactionDate);
    if (await _lockedMonths.isLocked(entityId, monthYear)) {
      throw MonthIsLockedException(monthYear);
    }

    return _repository.createSplit(
      entityId: entityId,
      contactId: contactId,
      transactionType: transactionType,
      receiptNumber: receiptNumber.trim(),
      paymentReference:
          TransactionValidator.normalisePaymentReference(paymentReference),
      transactionDate: transactionDate,
      isCash: isCash,
      bankAccountId: bankAccountId,
      lines: TransactionValidator.normaliseLines(lines),
    );
  }

  static String _monthYear(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
