import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/contact.dart';
import 'package:shedbooks_server/domain/exceptions/contact_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/application/contact/delete_contact_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

void main() {
  late MockContactRepository repository;
  late DeleteContactUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  final tContact = Contact(
    id: tId,
    name: 'Acme Corp',
    contactType: ContactType.company,
    gstRegistered: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockContactRepository();
    sut = DeleteContactUseCase(repository);
  });

  group('DeleteContactUseCase', () {
    test('calls repository delete when contact exists', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => tContact);
      when(() => repository.delete(tId)).thenAnswer((_) async {});

      // Act
      await sut.execute(tId);

      // Assert
      verify(() => repository.delete(tId)).called(1);
    });

    test('throws ContactNotFoundException when contact does not exist', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId),
        throwsA(isA<ContactNotFoundException>()),
      );
      verifyNever(() => repository.delete(any()));
    });
  });
}
