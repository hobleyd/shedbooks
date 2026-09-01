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

import 'package:shedbooks_server/presentation/dto/bank_match_request.dart';

void main() {
  group('BankMatchRequest.fromJson', () {
    test('parses transactionIds and bankAccountId with no transactionDate', () {
      final dto = BankMatchRequest.fromJson({
        'transactionIds': ['tx-1', 'tx-2'],
        'bankAccountId': 'acc-1',
      });

      expect(dto.transactionIds, equals(['tx-1', 'tx-2']));
      expect(dto.bankAccountId, equals('acc-1'));
      expect(dto.transactionDate, isNull);
    });

    test('parses transactionDate when present, so manual matches can be '
        're-detected by date on a later re-import', () {
      final dto = BankMatchRequest.fromJson({
        'transactionIds': ['tx-1'],
        'bankAccountId': 'acc-1',
        'transactionDate': '2026-08-15',
      });

      expect(dto.transactionDate, equals(DateTime.parse('2026-08-15')));
    });

    test('throws FormatException when transactionIds is missing', () {
      expect(
        () => BankMatchRequest.fromJson({'bankAccountId': 'acc-1'}),
        throwsFormatException,
      );
    });

    test('throws FormatException when transactionDate is not a valid date string', () {
      expect(
        () => BankMatchRequest.fromJson({
          'transactionIds': ['tx-1'],
          'transactionDate': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException when transactionDate is not a string', () {
      expect(
        () => BankMatchRequest.fromJson({
          'transactionIds': ['tx-1'],
          'transactionDate': 12345,
        }),
        throwsFormatException,
      );
    });
  });
}
