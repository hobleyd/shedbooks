import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/contact.dart';
import 'package:shedbooks_server/domain/exceptions/contact_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/application/contact/create_contact_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

void main() {
  late MockContactRepository repository;
  late CreateContactUseCase sut;

  const tEntityId = 'entity-1';
  final tCompany = Contact(
    id: '00000000-0000-0000-0000-000000000001',
    name: 'Acme Corp',
    contactType: ContactType.company,
    gstRegistered: true,
    abn: '51824753556',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  final tPerson = Contact(
    id: '00000000-0000-0000-0000-000000000002',
    name: 'Jane Smith',
    contactType: ContactType.person,
    gstRegistered: false,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockContactRepository();
    sut = CreateContactUseCase(repository);
    registerFallbackValue(ContactType.person);
  });

  group('CreateContactUseCase', () {
    test('creates a company contact with ABN and returns the persisted entity',
        () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          name: 'Acme Corp',
          contactType: ContactType.company,
          gstRegistered: true,
          abn: '51824753556',
        ),
      ).thenAnswer((_) async => tCompany);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        name: 'Acme Corp',
        contactType: ContactType.company,
        gstRegistered: true,
        abn: '51824753556',
      );

      // Assert
      expect(result, equals(tCompany));
    });

    test('creates a person contact with gstRegistered false', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          name: 'Jane Smith',
          contactType: ContactType.person,
          gstRegistered: false,
          abn: null,
        ),
      ).thenAnswer((_) async => tPerson);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        name: 'Jane Smith',
        contactType: ContactType.person,
        gstRegistered: false,
      );

      // Assert
      expect(result.gstRegistered, isFalse);
      expect(result.abn, isNull);
    });

    test(
        'throws ContactValidationException when person has gstRegistered true',
        () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Jane Smith',
          contactType: ContactType.person,
          gstRegistered: true,
        ),
        throwsA(isA<ContactValidationException>()),
      );
      verifyNever(
        () => repository.create(
          entityId: any(named: 'entityId'),
          name: any(named: 'name'),
          contactType: any(named: 'contactType'),
          gstRegistered: any(named: 'gstRegistered'),
        ),
      );
    });

    test('throws ContactValidationException when name is empty', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: '   ',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '51824753556',
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('throws ContactValidationException when company ABN is missing',
        () async {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Acme Corp',
          contactType: ContactType.company,
          gstRegistered: false,
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('throws ContactValidationException when company ABN is not 11 digits',
        () async {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Acme Corp',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '1234567',
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('throws ContactValidationException when person contact has an ABN',
        () async {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Jane Smith',
          contactType: ContactType.person,
          gstRegistered: false,
          abn: '51824753556',
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('trims whitespace from name before persisting', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          name: 'Acme Corp',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '51824753556',
        ),
      ).thenAnswer((_) async => tCompany);

      // Act
      await sut.execute(
        entityId: tEntityId,
        name: '  Acme Corp  ',
        contactType: ContactType.company,
        gstRegistered: false,
        abn: '51824753556',
      );

      // Assert
      verify(
        () => repository.create(
          entityId: tEntityId,
          name: 'Acme Corp',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '51824753556',
        ),
      ).called(1);
    });
  });
}
