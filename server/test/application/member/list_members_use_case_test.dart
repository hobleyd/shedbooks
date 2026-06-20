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

import 'package:shedbooks_server/application/member/list_members_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

void main() {
  late MockMemberRepository repository;
  late ListMembersUseCase sut;

  const tEntityId = 'entity-1';
  final tMembers = [
    Member(
      id: '00000000-0000-0000-0000-000000000001',
      entityId: tEntityId,
      firstName: 'Ron',
      lastName: 'Anderson',
      membershipStatus: '2026',
      etag: 'etag-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    Member(
      id: '00000000-0000-0000-0000-000000000002',
      entityId: tEntityId,
      firstName: 'Lynn',
      lastName: 'Bartlett',
      membershipStatus: 'FLM',
      etag: 'etag-2',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  setUp(() {
    repository = MockMemberRepository();
    sut = ListMembersUseCase(repository);
  });

  group('ListMembersUseCase', () {
    test('returns all members from repository', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => tMembers);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tMembers));
      verify(() => repository.findAll(entityId: tEntityId)).called(1);
    });

    test('returns an empty list when there are no members', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
