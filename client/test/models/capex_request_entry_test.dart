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
import 'package:shedbooks_client/models/capex_request_entry.dart';

void main() {
  Map<String, dynamic> json({
    String? invoiceId,
    String? invoiceNumber,
    int? invoiceTotalCents,
    int? actualSpentCents,
  }) =>
      {
        'id': '00000000-0000-0000-0000-000000000001',
        'requestNo': 'CER 26-012',
        'requestDate': '2026-07-01',
        'preparedByName': 'Rob Purves',
        'description': 'Signs',
        'whatIsRequested': 'Signs',
        'needOrBenefit': 'Visibility',
        'purchaseCostCents': 50000,
        'totalAmountCents': 50000,
        'status': 'approved',
        'actualSpentCents': actualSpentCents,
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'invoiceTotalCents': invoiceTotalCents,
      };

  group('CapexRequestEntry linked invoice', () {
    test('has no invoice or delta when none is linked', () {
      // Arrange
      final Map<String, dynamic> body = json();

      // Act
      final CapexRequestEntry entry = CapexRequestEntry.fromJson(body);

      // Assert
      expect(entry.invoiceId, isNull);
      expect(entry.invoiceDeltaCents, isNull);
    });

    test('delta is the invoice total minus the amount spent', () {
      // Arrange
      final Map<String, dynamic> body = json(
        invoiceId: '00000000-0000-0000-0000-0000000000aa',
        invoiceNumber: 'WMS-26-001',
        invoiceTotalCents: 55000,
      );

      // Act
      final CapexRequestEntry entry = CapexRequestEntry.fromJson(body);

      // Assert
      expect(entry.invoiceNumber, equals('WMS-26-001'));
      expect(entry.invoiceDeltaCents, equals(5000));
    });

    test('delta is negative when the invoice falls short', () {
      // Arrange
      final Map<String, dynamic> body = json(
        invoiceId: '00000000-0000-0000-0000-0000000000aa',
        invoiceNumber: 'WMS-26-001',
        invoiceTotalCents: 42000,
      );

      // Act
      final CapexRequestEntry entry = CapexRequestEntry.fromJson(body);

      // Assert
      expect(entry.invoiceDeltaCents, equals(-8000));
    });

    test('delta uses the actual amount spent once recorded', () {
      // Arrange
      final Map<String, dynamic> body = json(
        invoiceId: '00000000-0000-0000-0000-0000000000aa',
        invoiceNumber: 'WMS-26-001',
        invoiceTotalCents: 55000,
        actualSpentCents: 47500,
      );

      // Act
      final CapexRequestEntry entry = CapexRequestEntry.fromJson(body);

      // Assert
      expect(entry.amountSpentCents, equals(47500));
      expect(entry.invoiceDeltaCents, equals(7500));
    });
  });
}
