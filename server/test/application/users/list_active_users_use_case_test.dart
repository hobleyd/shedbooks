import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/user_presence.dart';
import 'package:shedbooks_server/domain/repositories/i_user_presence_repository.dart';
import 'package:shedbooks_server/application/users/list_active_users_use_case.dart';

class MockUserPresenceRepository extends Mock
    implements IUserPresenceRepository {}

void main() {
  late MockUserPresenceRepository repository;
  late ListActiveUsersUseCase sut;

  const tEntityId = 'org-abc123';
  final tNow = DateTime.utc(2026, 6, 4, 12, 0);
  final tUsers = [
    UserPresence(
      entityId: tEntityId,
      userId: 'auth0|alice',
      userEmail: 'alice@example.com',
      role: 'administrator',
      lastSeen: tNow,
      ipAddress: '1.2.3.4',
    ),
    UserPresence(
      entityId: tEntityId,
      userId: 'auth0|bob',
      userEmail: 'bob@example.com',
      role: 'contributor',
      lastSeen: tNow.subtract(const Duration(hours: 2)),
      ipAddress: '5.6.7.8',
    ),
  ];

  setUp(() {
    repository = MockUserPresenceRepository();
    sut = ListActiveUsersUseCase(repository);
  });

  group('ListActiveUsersUseCase', () {
    test('returns users from repository ordered by last_seen descending',
        () async {
      // Arrange
      when(() => repository.findAllByEntity(tEntityId))
          .thenAnswer((_) async => tUsers);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tUsers));
      verify(() => repository.findAllByEntity(tEntityId)).called(1);
    });

    test('returns empty list when no users have ever accessed the application',
        () async {
      // Arrange
      when(() => repository.findAllByEntity(tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });

    test('delegates directly to repository without filtering', () async {
      // Arrange — repository owns the ordering/filtering concern
      when(() => repository.findAllByEntity(tEntityId))
          .thenAnswer((_) async => tUsers);

      // Act
      await sut.execute(entityId: tEntityId);

      // Assert — exactly one repository call, no extra calls or mutation
      verify(() => repository.findAllByEntity(tEntityId)).called(1);
      verifyNoMoreInteractions(repository);
    });
  });
}
