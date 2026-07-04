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

import 'package:shedbooks_server/domain/entities/user_api_key.dart';
import 'package:shedbooks_server/domain/repositories/i_user_api_key_repository.dart';
import 'package:shedbooks_server/application/api_key/get_api_key_status_use_case.dart';

class MockUserApiKeyRepository extends Mock implements IUserApiKeyRepository {}

void main() {
  late MockUserApiKeyRepository repository;
  late GetApiKeyStatusUseCase sut;

  const tEntityId = 'entity-1';
  const tUserId = 'auth0|user1';
  const tUserEmail = 'test@example.com';

  setUp(() {
    repository = MockUserApiKeyRepository();
    sut = GetApiKeyStatusUseCase(repository);
  });

  group('execute', () {
    test('returns hasKey=false when no key exists for the user', () async {
      // Arrange
      when(() => repository.findByUser(entityId: tEntityId, userId: tUserId))
          .thenAnswer((_) async => null);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      expect(result.hasKey, isFalse);
      expect(result.username, equals(tUserEmail));
    });

    test('returns hasKey=true when a key exists for the user', () async {
      // Arrange
      final existingKey = UserApiKey(
        id: '00000000-0000-0000-0000-000000000001',
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
        apiKeyHash: 'a' * 64,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      when(() => repository.findByUser(entityId: tEntityId, userId: tUserId))
          .thenAnswer((_) async => existingKey);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      expect(result.hasKey, isTrue);
      expect(result.username, equals(tUserEmail));
    });

    test('passes the correct entityId and userId to the repository', () async {
      // Arrange
      when(() => repository.findByUser(entityId: tEntityId, userId: tUserId))
          .thenAnswer((_) async => null);

      // Act
      await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      verify(() => repository.findByUser(
            entityId: tEntityId,
            userId: tUserId,
          )).called(1);
    });
  });
}
