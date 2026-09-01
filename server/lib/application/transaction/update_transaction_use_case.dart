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
import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// Updates an existing transaction.
class UpdateTransactionUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const UpdateTransactionUseCase(this._repository, this._lockedMonths);

  Future<Transaction> execute({
    required String id,
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required String description,
    required DateTime transactionDate,
    bool? isCash,
    String? bankAccountId,
  }) async {
    TransactionValidator.validate(
      amount: amount,
      gstAmount: gstAmount,
      receiptNumber: receiptNumber,
    );

    // Check both the existing transaction's month and the new target month.
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw TransactionNotFoundException(id);

    final existingMonth = _monthYear(existing.transactionDate);
    if (await _lockedMonths.isLocked(entityId, existingMonth)) {
      throw MonthIsLockedException(existingMonth);
    }

    final newMonth = _monthYear(transactionDate);
    if (newMonth != existingMonth &&
        await _lockedMonths.isLocked(entityId, newMonth)) {
      throw MonthIsLockedException(newMonth);
    }

    return _repository.update(
      id: id,
      entityId: entityId,
      contactId: contactId,
      generalLedgerId: generalLedgerId,
      amount: amount,
      gstAmount: gstAmount,
      transactionType: transactionType,
      receiptNumber: receiptNumber.trim(),
      paymentReference: paymentReference?.trim().isEmpty ?? true
          ? null
          : paymentReference!.trim(),
      description: description.trim(),
      transactionDate: transactionDate,
      isCash: isCash ?? existing.isCash,
      // Cash transactions are pre-matched; otherwise preserve existing bank_matched state.
      bankMatched: (isCash ?? existing.isCash) || existing.bankMatched,
      // The account a transaction relates to can now be set directly by the
      // caller (e.g. the transaction form's account dropdown); when omitted,
      // preserve whatever was already recorded (including reconciliation matches).
      bankAccountId: bankAccountId ?? existing.bankAccountId,
    );
  }

  static String _monthYear(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
