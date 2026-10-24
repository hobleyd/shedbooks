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


import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/presentation/dto/create_transaction_request.dart';
import 'package:shedbooks_server/presentation/dto/split_transaction_request.dart';
import 'package:shedbooks_server/presentation/dto/update_transaction_request.dart';

void main() {
  Map<String, dynamic> singleBody([Map<String, dynamic> extra = const {}]) => {
        'contactId': '00000000-0000-0000-0000-000000000002',
        'generalLedgerId': '00000000-0000-0000-0000-000000000003',
        'amount': 5000,
        'gstAmount': 0,
        'transactionType': 'debit',
        'receiptNumber': 'P-26001',
        'transactionDate': '2026-10-24',
        ...extra,
      };

  Map<String, dynamic> splitBody([Map<String, dynamic> extra = const {}]) => {
        'contactId': '00000000-0000-0000-0000-000000000002',
        'transactionType': 'debit',
        'receiptNumber': 'P-26001',
        'transactionDate': '2026-10-24',
        'lines': [
          {
            'generalLedgerId': '00000000-0000-0000-0000-000000000003',
            'amount': 5000,
            'gstAmount': 0,
          },
        ],
        ...extra,
      };

  group('CreateTransactionRequest.fromJson paymentMethod', () {
    test('defaults to directDebit when omitted', () {
      // Arrange
      final json = singleBody();

      // Act
      final dto = CreateTransactionRequest.fromJson(json);

      // Assert
      expect(dto.paymentMethod, equals(PaymentMethod.directDebit));
    });

    test('parses bpay', () {
      // Arrange
      final json = singleBody({'paymentMethod': 'bpay'});

      // Act
      final dto = CreateTransactionRequest.fromJson(json);

      // Assert
      expect(dto.paymentMethod, equals(PaymentMethod.bpay));
    });

    test('rejects an unknown value', () {
      // Arrange
      final json = singleBody({'paymentMethod': 'cheque'});

      // Act / Assert
      expect(() => CreateTransactionRequest.fromJson(json),
          throwsA(isA<FormatException>()));
    });

    test('rejects a non-string value', () {
      // Arrange
      final json = singleBody({'paymentMethod': 1});

      // Act / Assert
      expect(() => CreateTransactionRequest.fromJson(json),
          throwsA(isA<FormatException>()));
    });
  });

  group('UpdateTransactionRequest.fromJson paymentMethod', () {
    test('is null when omitted so the existing value is kept', () {
      // Arrange
      final json = singleBody();

      // Act
      final dto = UpdateTransactionRequest.fromJson(json);

      // Assert
      expect(dto.paymentMethod, isNull);
    });

    test('parses directDebit', () {
      // Arrange
      final json = singleBody({'paymentMethod': 'directDebit'});

      // Act
      final dto = UpdateTransactionRequest.fromJson(json);

      // Assert
      expect(dto.paymentMethod, equals(PaymentMethod.directDebit));
    });
  });

  group('SplitTransactionRequest.fromJson paymentMethod', () {
    test('is null when omitted', () {
      // Arrange
      final json = splitBody();

      // Act
      final dto = SplitTransactionRequest.fromJson(json);

      // Assert
      expect(dto.paymentMethod, isNull);
    });

    test('parses bpay', () {
      // Arrange
      final json = splitBody({'paymentMethod': 'bpay'});

      // Act
      final dto = SplitTransactionRequest.fromJson(json);

      // Assert
      expect(dto.paymentMethod, equals(PaymentMethod.bpay));
    });

    test('rejects an unknown value', () {
      // Arrange
      final json = splitBody({'paymentMethod': 'BPAY'});

      // Act / Assert
      expect(() => SplitTransactionRequest.fromJson(json),
          throwsA(isA<FormatException>()));
    });
  });
}
