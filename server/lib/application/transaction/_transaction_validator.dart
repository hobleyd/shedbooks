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

import '../../domain/entities/transaction_line.dart';
import '../../domain/exceptions/transaction_exception.dart';

/// Shared validation logic for transaction use cases.
abstract final class TransactionValidator {
  /// The most general ledger lines a single split transaction may carry.
  static const int maxSplitLines = 50;

  /// Validates the lines of a split transaction: there must be between
  /// [minLines] and [maxSplitLines] of them, and each must satisfy the same
  /// amount / GST rules as an ordinary transaction.
  static void validateLines({
    required List<TransactionLine> lines,
    required String receiptNumber,
    required int minLines,
  }) {
    if (lines.length < minLines) {
      throw TransactionValidationException(
        minLines > 1
            ? 'A split transaction needs at least $minLines lines'
            : 'At least one line is required',
      );
    }
    if (lines.length > maxSplitLines) {
      throw const TransactionValidationException(
        'A split transaction may have at most $maxSplitLines lines',
      );
    }
    for (final TransactionLine line in lines) {
      if (line.generalLedgerId.trim().isEmpty) {
        throw const TransactionValidationException(
          'Every line must have a general ledger account',
        );
      }
      validate(
        amount: line.amount,
        gstAmount: line.gstAmount,
        receiptNumber: receiptNumber,
      );
    }
  }

  /// Returns [lines] with each description trimmed.
  static List<TransactionLine> normaliseLines(List<TransactionLine> lines) => [
        for (final TransactionLine line in lines)
          TransactionLine(
            generalLedgerId: line.generalLedgerId,
            amount: line.amount,
            gstAmount: line.gstAmount,
            description: line.description.trim(),
          ),
      ];

  /// Returns [paymentReference] trimmed, or null when blank.
  static String? normalisePaymentReference(String? paymentReference) =>
      paymentReference?.trim().isEmpty ?? true ? null : paymentReference!.trim();

  static void validate({
    required int amount,
    required int gstAmount,
    required String receiptNumber,
  }) {
    if (amount <= 0) {
      throw const TransactionValidationException(
        'Amount must be greater than zero',
      );
    }
    if (gstAmount < 0) {
      throw const TransactionValidationException(
        'GST amount must not be negative',
      );
    }
    if (gstAmount > amount) {
      throw const TransactionValidationException(
        'GST amount must not exceed the transaction amount',
      );
    }
    if (receiptNumber.trim().isEmpty) {
      throw const TransactionValidationException(
        'Receipt number must not be empty',
      );
    }
  }
}
