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

import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/payment_method.dart';
import 'package:shedbooks_client/models/transaction_entry.dart';

void main() {
  Map<String, dynamic> json([Map<String, dynamic> extra = const {}]) => {
        'id': 't1',
        'contactId': 'c1',
        'generalLedgerId': 'gl1',
        'receiptNumber': 'P-26001',
        'transactionType': 'debit',
        'amount': 1000,
        'gstAmount': 100,
        'totalAmount': 1100,
        'transactionDate': '2026-10-24',
        ...extra,
      };

  group('TransactionEntry.fromJson paymentMethod', () {
    test('reads bpay', () {
      // Act
      final TransactionEntry t =
          TransactionEntry.fromJson(json({'paymentMethod': 'bpay'}));

      // Assert
      expect(t.paymentMethod, PaymentMethod.bpay);
      expect(t.isBpay, isTrue);
    });

    test('defaults to Direct Debit when absent', () {
      // Act
      final TransactionEntry t = TransactionEntry.fromJson(json());

      // Assert
      expect(t.paymentMethod, PaymentMethod.directDebit);
      expect(t.isBpay, isFalse);
    });

    test('copyWith keeps the payment method', () {
      // Arrange
      final TransactionEntry t =
          TransactionEntry.fromJson(json({'paymentMethod': 'bpay'}));

      // Act
      final TransactionEntry copy = t.copyWith(bankMatched: true);

      // Assert
      expect(copy.paymentMethod, PaymentMethod.bpay);
    });
  });
}
