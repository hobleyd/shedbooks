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

import 'package:shedbooks_server/application/member/delete_member_use_case.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

void main() {
  late MockMemberRepository repository;
  late DeleteMemberUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockMemberRepository();
    sut = DeleteMemberUseCase(repository);
  });

  group('DeleteMemberUseCase', () {
    test('delegates deletion to repository', () async {
      // Arrange
      when(() => repository.delete(tId, entityId: tEntityId))
          .thenAnswer((_) async {});

      // Act
      await sut.execute(tId, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(tId, entityId: tEntityId)).called(1);
    });

    test('propagates MemberNotFoundException from repository', () async {
      // Arrange
      when(() => repository.delete(tId, entityId: tEntityId))
          .thenThrow(MemberNotFoundException(tId));

      // Act & Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<MemberNotFoundException>()),
      );
    });
  });
}
