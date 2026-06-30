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

import 'package:shedbooks_server/application/entity/get_next_invoice_number_use_case.dart';

void main() {
  group('GetNextInvoiceNumberUseCase.generateNext', () {
    final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');
    final yyyy = DateTime.now().year.toString();

    test('returns 001 for default WMS-YY-### with no prior numbers', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'WMS-YY-###',
        [],
      );

      // Assert
      expect(result, equals('WMS-$yy-001'));
    });

    test('increments the maximum existing sequential number', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'WMS-YY-###',
        ['WMS-$yy-001', 'WMS-$yy-005', 'WMS-$yy-003'],
      );

      // Assert
      expect(result, equals('WMS-$yy-006'));
    });

    test('ignores numbers from a different year prefix', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'WMS-YY-###',
        ['WMS-24-099', 'WMS-25-050'],
      );

      // Assert — prior years are irrelevant; starts at 001
      expect(result, equals('WMS-$yy-001'));
    });

    test('pads number to hash-count width', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'INV-YYYY-#####',
        ['INV-$yyyy-00099'],
      );

      // Assert
      expect(result, equals('INV-$yyyy-00100'));
    });

    test('returns resolved format unchanged when no # tokens present', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'FIXED-FORMAT',
        [],
      );

      // Assert
      expect(result, equals('FIXED-FORMAT'));
    });

    test('handles suffix after sequential digits', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'YY-##-END',
        ['$yy-07-END'],
      );

      // Assert
      expect(result, equals('$yy-08-END'));
    });
  });
}
