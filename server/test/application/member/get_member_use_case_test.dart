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

import 'package:shedbooks_server/application/member/get_member_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

void main() {
  late MockMemberRepository repository;
  late GetMemberUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tMember = Member(
    id: tId,
    entityId: tEntityId,
    firstName: 'Ron',
    lastName: 'Anderson',
    membershipStatus: '2026',
    etag: 'etag-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockMemberRepository();
    sut = GetMemberUseCase(repository);
  });

  group('GetMemberUseCase', () {
    test('returns the member when found', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      // Act
      final result = await sut.execute(tId, entityId: tEntityId);

      // Assert
      expect(result, equals(tMember));
      verify(() => repository.findById(tId, entityId: tEntityId)).called(1);
    });

    test('throws MemberNotFoundException when repository returns null',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<MemberNotFoundException>()),
      );
    });

    test('does not call repository for a different entity', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: 'entity-2'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => sut.execute(tId, entityId: 'entity-2'),
        throwsA(isA<MemberNotFoundException>()),
      );
      verify(() => repository.findById(tId, entityId: 'entity-2')).called(1);
    });
  });
}
