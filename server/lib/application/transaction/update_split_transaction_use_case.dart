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
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// The rows a split update replaced ([before]) and wrote ([after]).
typedef SplitUpdateResult = ({List<Transaction> before, List<Transaction> after});

/// Replaces a transaction — and, when it is one line of a split, every line
/// of that split — with a new set of general ledger lines.
///
/// This is how an ordinary transaction becomes a split (more than one line
/// supplied), how a split is edited, and how a split collapses back into an
/// ordinary transaction (exactly one line supplied).
class UpdateSplitTransactionUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const UpdateSplitTransactionUseCase(this._repository, this._lockedMonths);

  /// Replaces the transaction [id] (with its split siblings, if any) by
  /// [lines]. Both the existing month and the new target month must be
  /// unlocked. Bank-matched state, ABA batch name and — unless overridden —
  /// the cash flag and bank account carry over from the replaced rows.
  /// Throws [TransactionNotFoundException] if [id] does not exist within [entityId].
  Future<SplitUpdateResult> execute({
    required String id,
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    bool? isCash,
    String? bankAccountId,
    required List<TransactionLine> lines,
  }) async {
    TransactionValidator.validateLines(
      lines: lines,
      receiptNumber: receiptNumber,
      minLines: 1,
    );

    final Transaction? existing =
        await _repository.findById(id, entityId: entityId);
    if (existing == null) throw TransactionNotFoundException(id);

    final String? splitGroupId = existing.splitGroupId;
    final List<Transaction> before = splitGroupId == null
        ? [existing]
        : await _repository.findBySplitGroup(splitGroupId, entityId: entityId);

    final existingMonth = _monthYear(existing.transactionDate);
    if (await _lockedMonths.isLocked(entityId, existingMonth)) {
      throw MonthIsLockedException(existingMonth);
    }

    final newMonth = _monthYear(transactionDate);
    if (newMonth != existingMonth &&
        await _lockedMonths.isLocked(entityId, newMonth)) {
      throw MonthIsLockedException(newMonth);
    }

    final bool cash = isCash ?? existing.isCash;
    final List<Transaction> after = await _repository.replaceWithLines(
      replacedIds: [for (final Transaction t in before) t.id],
      entityId: entityId,
      contactId: contactId,
      transactionType: transactionType,
      receiptNumber: receiptNumber.trim(),
      paymentReference:
          TransactionValidator.normalisePaymentReference(paymentReference),
      transactionDate: transactionDate,
      isCash: cash,
      // Cash transactions are pre-matched; otherwise preserve existing bank_matched state.
      bankMatched: cash || before.any((Transaction t) => t.bankMatched),
      abaBatchName: existing.abaBatchName,
      bankAccountId: bankAccountId ?? existing.bankAccountId,
      lines: TransactionValidator.normaliseLines(lines),
    );

    return (before: before, after: after);
  }

  static String _monthYear(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
