import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/get_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late GetTransactionUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tTransaction = Transaction(
    id: tId,
    contactId: '00000000-0000-0000-0000-000000000002',
    generalLedgerId: '00000000-0000-0000-0000-000000000003',
    amount: 5500,
    gstAmount: 500,
    transactionType: TransactionType.credit,
    receiptNumber: 'REC-002',
    description: '',
    transactionDate: DateTime.utc(2026, 3, 15),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockTransactionRepository();
    sut = GetTransactionUseCase(repository);
  });

  group('GetTransactionUseCase', () {
    test('returns the transaction when found', () async {
      // Arrange
      when(
        () => repository.findById(tId, entityId: tEntityId),
      ).thenAnswer((_) async => tTransaction);

      // Act
      final result = await sut.execute(tId, entityId: tEntityId);

      // Assert
      expect(result, equals(tTransaction));
      expect(result.totalAmount, equals(6000));
    });

    test('throws TransactionNotFoundException when transaction does not exist', () async {
      // Arrange
      when(
        () => repository.findById(tId, entityId: tEntityId),
      ).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });
  });
}
