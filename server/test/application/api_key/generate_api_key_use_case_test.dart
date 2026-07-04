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
import 'package:shedbooks_server/application/api_key/generate_api_key_use_case.dart';

class MockUserApiKeyRepository extends Mock implements IUserApiKeyRepository {}

void main() {
  late MockUserApiKeyRepository repository;
  late GenerateApiKeyUseCase sut;

  const tEntityId = 'entity-1';
  const tUserId = 'auth0|user1';
  const tUserEmail = 'test@example.com';

  setUp(() {
    repository = MockUserApiKeyRepository();
    sut = GenerateApiKeyUseCase(repository);
    registerFallbackValue(UserApiKey(
      id: '00000000-0000-0000-0000-000000000000',
      entityId: '',
      userId: '',
      userEmail: '',
      apiKeyHash: '',
      createdAt: DateTime.utc(2026, 1, 1),
    ));
  });

  group('execute', () {
    test('returns a non-empty API key and the user email as username', () async {
      // Arrange
      when(() => repository.upsert(any())).thenAnswer((_) async {});

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      expect(result.apiKey, isNotEmpty);
      expect(result.username, equals(tUserEmail));
    });

    test('stores a SHA-256 hash, not the raw key', () async {
      // Arrange
      UserApiKey? captured;
      when(() => repository.upsert(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as UserApiKey;
      });

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      expect(captured, isNotNull);
      expect(captured!.apiKeyHash, isNot(equals(result.apiKey)));
      // SHA-256 hex digest is always 64 characters.
      expect(captured!.apiKeyHash.length, equals(64));
    });

    test('persists the correct entityId, userId, and userEmail', () async {
      // Arrange
      UserApiKey? captured;
      when(() => repository.upsert(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as UserApiKey;
      });

      // Act
      await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      expect(captured!.entityId, equals(tEntityId));
      expect(captured!.userId, equals(tUserId));
      expect(captured!.userEmail, equals(tUserEmail));
    });

    test('each invocation generates a different key', () async {
      // Arrange
      when(() => repository.upsert(any())).thenAnswer((_) async {});

      // Act
      final result1 = await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );
      final result2 = await sut.execute(
        entityId: tEntityId,
        userId: tUserId,
        userEmail: tUserEmail,
      );

      // Assert
      expect(result1.apiKey, isNot(equals(result2.apiKey)));
    });
  });
}
