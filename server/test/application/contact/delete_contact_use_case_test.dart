import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/contact.dart';
import 'package:shedbooks_server/domain/exceptions/contact_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/contact/delete_contact_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockContactRepository repository;
  late MockTransactionRepository transactions;
  late DeleteContactUseCase sut;

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
    transactions = MockTransactionRepository();
    sut = DeleteContactUseCase(repository, transactions);
  });

  group('DeleteContactUseCase', () {
    test('calls repository delete when contact exists and has no transactions',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tContact);
      when(() => transactions.hasTransactions(tId, entityId: tEntityId))
          .thenAnswer((_) async => false);
      when(() => repository.delete(tId, entityId: tEntityId))
          .thenAnswer((_) async {});

      // Act
      await sut.execute(tId, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(tId, entityId: tEntityId)).called(1);
    });

    test('throws ContactHasTransactionsException when contact has transactions',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tContact);
      when(() => transactions.hasTransactions(tId, entityId: tEntityId))
          .thenAnswer((_) async => true);

      // Act / Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<ContactInUseException>()),
      );
      verifyNever(
        () => repository.delete(any(), entityId: any(named: 'entityId')),
      );
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
      verifyNever(
        () => repository.delete(any(), entityId: any(named: 'entityId')),
      );
    });
  });
}
