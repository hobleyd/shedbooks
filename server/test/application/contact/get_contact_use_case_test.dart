import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/contact.dart';
import 'package:shedbooks_server/domain/exceptions/contact_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/application/contact/get_contact_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

void main() {
  late MockContactRepository repository;
  late GetContactUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tContact = Contact(
    id: tId,
    name: 'Acme Corp',
    contactType: ContactType.company,
    gstRegistered: true,
    abn: '51824753556',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockContactRepository();
    sut = GetContactUseCase(repository);
  });

  group('GetContactUseCase', () {
    test('returns the contact when found', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tContact);

      // Act
      final result = await sut.execute(tId, entityId: tEntityId);

      // Assert
      expect(result, equals(tContact));
    });

    test('throws ContactNotFoundException when contact does not exist',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<ContactNotFoundException>()),
      );
    });
  });
}
