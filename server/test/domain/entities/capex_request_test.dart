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

import 'package:shedbooks_server/domain/entities/capex_request.dart';

void main() {
  final DateTime tDate = DateTime.utc(2026, 7, 1);

  CapexRequest makeRequest({int? invoiceTotalCents, int? actualSpentCents}) => CapexRequest(
        id: '00000000-0000-0000-0000-000000000001',
        entityId: 'entity-1',
        requestNo: 'CER 26-012',
        requestDate: tDate,
        preparedByName: 'Rob Purves',
        description: 'Signs',
        whatIsRequested: 'Signs',
        needOrBenefit: 'Visibility',
        purchaseCostCents: 50000,
        totalAmountCents: 50000,
        invoiceTotalCents: invoiceTotalCents,
        actualSpentCents: actualSpentCents,
        createdAt: tDate,
        updatedAt: tDate,
      );

  group('CapexRequest.invoiceDeltaCents', () {
    test('is null when no invoice is linked', () {
      // Arrange
      final CapexRequest request = makeRequest();

      // Act
      final int? delta = request.invoiceDeltaCents;

      // Assert
      expect(delta, isNull);
    });

    test('is positive when the invoice exceeds the amount spent', () {
      // Arrange
      final CapexRequest request = makeRequest(invoiceTotalCents: 55000);

      // Act
      final int? delta = request.invoiceDeltaCents;

      // Assert
      expect(delta, equals(5000));
    });

    test('is negative when the invoice falls short of the amount spent', () {
      // Arrange
      final CapexRequest request = makeRequest(invoiceTotalCents: 42000);

      // Act
      final int? delta = request.invoiceDeltaCents;

      // Assert
      expect(delta, equals(-8000));
    });

    test('uses the actual amount spent, once recorded, instead of the requested total', () {
      // Arrange
      final CapexRequest request =
          makeRequest(invoiceTotalCents: 55000, actualSpentCents: 47500);

      // Act
      final int? delta = request.invoiceDeltaCents;

      // Assert
      expect(request.amountSpentCents, equals(47500));
      expect(delta, equals(7500));
    });
  });
}
