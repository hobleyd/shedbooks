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

import '../../domain/exceptions/transaction_exception.dart';

/// Shared validation logic for transaction use cases.
abstract final class TransactionValidator {
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
