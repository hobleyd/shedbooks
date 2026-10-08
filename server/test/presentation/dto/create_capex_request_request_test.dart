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

import 'package:shedbooks_server/presentation/dto/create_capex_request_request.dart';

void main() {
  Map<String, dynamic> body({Object? invoiceId}) => {
        'requestNo': 'CER 26-012',
        'requestDate': '2026-07-01',
        'preparedByName': 'Rob Purves',
        'description': 'Signs',
        'whatIsRequested': 'Signs',
        'needOrBenefit': 'Visibility',
        'purchaseCostCents': 54450,
        'totalAmountCents': 54450,
        'invoiceId': invoiceId,
      };

  group('CreateCapexRequestRequest.fromJson invoiceId', () {
    test('is null when omitted', () {
      // Arrange
      final Map<String, dynamic> json = body();

      // Act
      final CreateCapexRequestRequest dto = CreateCapexRequestRequest.fromJson(json);

      // Assert
      expect(dto.invoiceId, isNull);
    });

    test('accepts a UUID', () {
      // Arrange
      const String id = '00000000-0000-0000-0000-0000000000aa';

      // Act
      final CreateCapexRequestRequest dto =
          CreateCapexRequestRequest.fromJson(body(invoiceId: id));

      // Assert
      expect(dto.invoiceId, equals(id));
    });

    test('rejects a value that is not a UUID', () {
      // Arrange
      final Map<String, dynamic> json = body(invoiceId: "x' OR 1=1");

      // Act + Assert
      expect(() => CreateCapexRequestRequest.fromJson(json), throwsFormatException);
    });
  });
}
