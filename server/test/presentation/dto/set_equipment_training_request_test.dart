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

import 'package:shedbooks_server/presentation/dto/set_equipment_training_request.dart';

void main() {
  const tId = '0A000000-0000-0000-0000-0000000000A1';

  group('SetEquipmentTrainingRequest.fromJson', () {
    test('parses asset ids (lower-cased, de-duplicated) and trainedOn', () {
      // Act
      final dto = SetEquipmentTrainingRequest.fromJson({
        'assetIds': [tId, tId.toLowerCase()],
        'trainedOn': '2026-10-08',
      });

      // Assert
      expect(dto.assetIds, equals({tId.toLowerCase()}));
      expect(dto.trainedOn, equals(DateTime(2026, 10, 8)));
    });

    test('accepts an empty list and a missing trainedOn', () {
      // Act
      final dto = SetEquipmentTrainingRequest.fromJson({'assetIds': []});

      // Assert
      expect(dto.assetIds, isEmpty);
      expect(dto.trainedOn, isNull);
    });

    test('rejects a missing or non-array assetIds', () {
      expect(() => SetEquipmentTrainingRequest.fromJson({}),
          throwsFormatException);
      expect(() => SetEquipmentTrainingRequest.fromJson({'assetIds': tId}),
          throwsFormatException);
    });

    test('rejects non-UUID asset ids', () {
      expect(
        () => SetEquipmentTrainingRequest.fromJson({
          'assetIds': ["x' OR 1=1 --"],
        }),
        throwsFormatException,
      );
      expect(
        () => SetEquipmentTrainingRequest.fromJson({
          'assetIds': [42],
        }),
        throwsFormatException,
      );
    });

    test('rejects a trainedOn that is not YYYY-MM-DD', () {
      expect(
        () => SetEquipmentTrainingRequest.fromJson({
          'assetIds': [],
          'trainedOn': '08/10/2026',
        }),
        throwsFormatException,
      );
    });
  });
}
