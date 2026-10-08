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

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/member/list_member_equipment_training_use_case.dart';
import 'package:shedbooks_server/application/member/list_training_equipment_use_case.dart';
import 'package:shedbooks_server/domain/entities/member_equipment_training.dart';
import 'package:shedbooks_server/domain/repositories/i_member_equipment_training_repository.dart';

class MockTrainingRepository extends Mock
    implements IMemberEquipmentTrainingRepository {}

void main() {
  late MockTrainingRepository repository;

  const tEntityId = 'entity-1';
  const tSaw = TrainingEquipment(
    assetId: 'a1',
    assetNo: '2026-W-0001',
    section: 'Wood Shop',
    description: 'Band Saw',
  );
  const tLathe = TrainingEquipment(
    assetId: 'a2',
    assetNo: '2026-M-0001',
    section: 'Metal Shop',
  );
  MemberEquipmentTraining record(String memberId, TrainingEquipment e) =>
      MemberEquipmentTraining(
        memberId: memberId,
        equipment: e,
        trainedOn: DateTime.utc(2026, 10, 8),
      );

  setUp(() => repository = MockTrainingRepository());

  group('ListMemberEquipmentTrainingUseCase', () {
    test('groups the entity\'s records by member id', () async {
      // Arrange
      final sawForM1 = record('m1', tSaw);
      final latheForM1 = record('m1', tLathe);
      final sawForM2 = record('m2', tSaw);
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => [sawForM1, latheForM1, sawForM2]);
      final sut = ListMemberEquipmentTrainingUseCase(repository);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result.keys, unorderedEquals(['m1', 'm2']));
      expect(result['m1'], equals([sawForM1, latheForM1]));
      expect(result['m2'], equals([sawForM2]));
    });

    test('executeForMember delegates to the repository', () async {
      // Arrange
      final records = [record('m1', tSaw)];
      when(() => repository.findForMember('m1', entityId: tEntityId))
          .thenAnswer((_) async => records);
      final sut = ListMemberEquipmentTrainingUseCase(repository);

      // Act
      final result = await sut.executeForMember('m1', entityId: tEntityId);

      // Assert
      expect(result, same(records));
    });
  });

  group('ListTrainingEquipmentUseCase', () {
    test('returns the repository\'s trainable equipment', () async {
      // Arrange
      when(() => repository.findEquipment(entityId: tEntityId))
          .thenAnswer((_) async => [tSaw, tLathe]);
      final sut = ListTrainingEquipmentUseCase(repository);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals([tSaw, tLathe]));
    });
  });

  group('TrainingSection.fromAssetType', () {
    test('matches section names ignoring case and surrounding space', () {
      expect(TrainingSection.fromAssetType(' wood shop '),
          TrainingSection.woodShop);
      expect(TrainingSection.fromAssetType('METAL SHOP'),
          TrainingSection.metalShop);
    });

    test('returns null for a non-training section', () {
      expect(TrainingSection.fromAssetType('Nursery'), isNull);
    });
  });
}
