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
import 'package:shedbooks_client/models/equipment_training.dart';
import 'package:shedbooks_client/models/member_entry.dart';

void main() {
  group('MemberEntry.fromJson', () {
    Map<String, dynamic> json(Object? role) => <String, dynamic>{
          'id': 'm1',
          'firstName': 'Ada',
          'lastName': 'Lovelace',
          'shedbooksAppRole': role,
          'etag': 'e1',
        };

    test('keeps an assigned role', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json('viewer'));

      // Assert
      expect(sut.shedbooksAppRole, 'viewer');
    });

    test('treats an empty-string role as no access', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json(''));

      // Assert
      expect(sut.shedbooksAppRole, isNull);
    });

    test('treats a null role as no access', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json(null));

      // Assert
      expect(sut.shedbooksAppRole, isNull);
    });
  });

  group('MemberEntry.fromJson equipmentTraining', () {
    Map<String, dynamic> json(Object? training) => <String, dynamic>{
          'id': 'm1',
          'firstName': 'Ada',
          'lastName': 'Lovelace',
          'etag': 'e1',
          if (training != null) 'equipmentTraining': training,
        };

    test('parses each trained item with its equipment and date', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json([
        {
          'assetId': 'a1',
          'assetNo': '2026-W-0002',
          'section': 'Wood Shop',
          'description': 'Band Saw - 14 inch',
          'brand': null,
          'trainedOn': '2026-10-08',
        },
      ]));

      // Assert
      expect(sut.equipmentTraining, hasLength(1));
      expect(sut.equipmentTraining.single.equipment.label, 'Band Saw - 14 inch');
      expect(sut.equipmentTraining.single.equipment.isInSection(kWoodShopSection),
          isTrue);
      expect(sut.equipmentTraining.single.trainedOn, '2026-10-08');
    });

    test('is empty when the key is absent', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json(null));

      // Assert
      expect(sut.equipmentTraining, isEmpty);
    });
  });

  group('TrainingEquipment', () {
    test('label falls back to the asset number without a description', () {
      // Arrange
      const TrainingEquipment sut = TrainingEquipment(
          assetId: 'a1', assetNo: '2026-M-0001', section: 'metal shop ');

      // Act / Assert
      expect(sut.label, '2026-M-0001');
      expect(sut.isInSection(kMetalShopSection), isTrue);
      expect(sut.isInSection(kWoodShopSection), isFalse);
    });
  });
}
