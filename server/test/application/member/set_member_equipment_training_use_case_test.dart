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

import 'package:shedbooks_server/application/member/set_member_equipment_training_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/entities/member_equipment_training.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_equipment_training_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

class MockTrainingRepository extends Mock
    implements IMemberEquipmentTrainingRepository {}

void main() {
  late MockMemberRepository members;
  late MockTrainingRepository training;
  late SetMemberEquipmentTrainingUseCase sut;

  const tMemberId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  const tSaw = TrainingEquipment(
    assetId: '00000000-0000-0000-0000-0000000000a1',
    assetNo: '2026-W-0001',
    section: 'Wood Shop',
    description: 'Band Saw',
  );
  const tLathe = TrainingEquipment(
    assetId: '00000000-0000-0000-0000-0000000000a2',
    assetNo: '2026-M-0001',
    section: 'Metal Shop',
    description: 'Lathe',
  );
  final tMember = Member(
    id: tMemberId,
    entityId: tEntityId,
    firstName: 'Jo',
    lastName: 'Bloggs',
    etag: 'etag',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() {
    members = MockMemberRepository();
    training = MockTrainingRepository();
    sut = SetMemberEquipmentTrainingUseCase(members, training);

    when(() => members.findById(tMemberId, entityId: tEntityId))
        .thenAnswer((_) async => tMember);
    when(() => training.findEquipment(entityId: tEntityId))
        .thenAnswer((_) async => [tSaw, tLathe]);
    when(() => training.findForMember(tMemberId, entityId: tEntityId))
        .thenAnswer((_) async => []);
    when(() => training.replaceForMember(
          memberId: any(named: 'memberId'),
          entityId: any(named: 'entityId'),
          assetIds: any(named: 'assetIds'),
          trainedOn: any(named: 'trainedOn'),
        )).thenAnswer((_) async => []);
  });

  group('SetMemberEquipmentTrainingUseCase', () {
    test('replaces the member\'s training with the given equipment', () async {
      // Arrange
      final saved = [
        MemberEquipmentTraining(
          memberId: tMemberId,
          equipment: tSaw,
          trainedOn: DateTime.utc(2026, 10, 8),
        ),
      ];
      when(() => training.replaceForMember(
            memberId: tMemberId,
            entityId: tEntityId,
            assetIds: {tSaw.assetId},
            trainedOn: DateTime.utc(2026, 10, 8),
          )).thenAnswer((_) async => saved);

      // Act
      final result = await sut.execute(
        memberId: tMemberId,
        entityId: tEntityId,
        assetIds: {tSaw.assetId},
        trainedOn: DateTime.utc(2026, 10, 8),
      );

      // Assert
      expect(result, same(saved));
    });

    test('truncates trainedOn to a UTC calendar date', () async {
      // Arrange
      final localLateEvening = DateTime(2026, 10, 8, 23, 45);

      // Act
      await sut.execute(
        memberId: tMemberId,
        entityId: tEntityId,
        assetIds: {tLathe.assetId},
        trainedOn: localLateEvening,
      );

      // Assert
      verify(() => training.replaceForMember(
            memberId: tMemberId,
            entityId: tEntityId,
            assetIds: {tLathe.assetId},
            trainedOn: DateTime.utc(2026, 10, 8),
          )).called(1);
    });

    test('an empty set clears training without looking up equipment',
        () async {
      // Act
      await sut.execute(
        memberId: tMemberId,
        entityId: tEntityId,
        assetIds: {},
        trainedOn: DateTime.utc(2026, 10, 8),
      );

      // Assert
      verifyNever(() => training.findEquipment(entityId: tEntityId));
      verify(() => training.replaceForMember(
            memberId: tMemberId,
            entityId: tEntityId,
            assetIds: <String>{},
            trainedOn: DateTime.utc(2026, 10, 8),
          )).called(1);
    });

    test(
        'keeps equipment the member is already trained on even after it has '
        'left the training Sections', () async {
      // Arrange
      const tMoved = TrainingEquipment(
        assetId: '00000000-0000-0000-0000-0000000000a3',
        assetNo: '2026-W-0009',
        section: 'Office',
      );
      when(() => training.findForMember(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => [
                MemberEquipmentTraining(
                  memberId: tMemberId,
                  equipment: tMoved,
                  trainedOn: DateTime.utc(2026, 1, 1),
                ),
              ]);

      // Act
      await sut.execute(
        memberId: tMemberId,
        entityId: tEntityId,
        assetIds: {tMoved.assetId, tSaw.assetId},
        trainedOn: DateTime.utc(2026, 10, 8),
      );

      // Assert
      verify(() => training.replaceForMember(
            memberId: tMemberId,
            entityId: tEntityId,
            assetIds: {tMoved.assetId, tSaw.assetId},
            trainedOn: DateTime.utc(2026, 10, 8),
          )).called(1);
    });

    test('throws MemberNotFoundException when the member is not in the entity',
        () async {
      // Arrange
      when(() => members.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act & Assert
      await expectLater(
        () => sut.execute(
          memberId: tMemberId,
          entityId: tEntityId,
          assetIds: {tSaw.assetId},
          trainedOn: DateTime.utc(2026, 10, 8),
        ),
        throwsA(isA<MemberNotFoundException>()),
      );
      verifyNever(() => training.replaceForMember(
            memberId: any(named: 'memberId'),
            entityId: any(named: 'entityId'),
            assetIds: any(named: 'assetIds'),
            trainedOn: any(named: 'trainedOn'),
          ));
    });

    test(
        'rejects an asset that is not Wood/Metal Shop equipment of the entity '
        '(other section or other entity)', () async {
      // Arrange
      const foreignAssetId = '00000000-0000-0000-0000-0000000000ff';

      // Act & Assert
      await expectLater(
        () => sut.execute(
          memberId: tMemberId,
          entityId: tEntityId,
          assetIds: {tSaw.assetId, foreignAssetId},
          trainedOn: DateTime.utc(2026, 10, 8),
        ),
        throwsA(isA<MemberValidationException>()),
      );
      verifyNever(() => training.replaceForMember(
            memberId: any(named: 'memberId'),
            entityId: any(named: 'entityId'),
            assetIds: any(named: 'assetIds'),
            trainedOn: any(named: 'trainedOn'),
          ));
    });
  });
}
