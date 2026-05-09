import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/contact.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/application/contact/list_contacts_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

void main() {
  late MockContactRepository repository;
  late ListContactsUseCase sut;

  const tEntityId = 'entity-1';
  final tContacts = [
    Contact(
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Acme Corp',
      contactType: ContactType.company,
      gstRegistered: true,
      abn: '51824753556',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    Contact(
      id: '00000000-0000-0000-0000-000000000002',
      name: 'Jane Smith',
      contactType: ContactType.person,
      gstRegistered: false,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
  ];

  setUp(() {
    repository = MockContactRepository();
    sut = ListContactsUseCase(repository);
  });

  group('ListContactsUseCase', () {
    test('returns all active contacts from repository', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => tContacts);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tContacts));
      verify(() => repository.findAll(entityId: tEntityId)).called(1);
    });

    test('returns empty list when no contacts exist', () async {
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
