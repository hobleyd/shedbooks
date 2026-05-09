import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/update_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late UpdateTransactionUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 5, 1);
  final tUpdated = Transaction(
    id: tId,
    contactId: '00000000-0000-0000-0000-000000000002',
    generalLedgerId: '00000000-0000-0000-0000-000000000003',
    amount: 22000,
    gstAmount: 2000,
    transactionType: TransactionType.debit,
    receiptNumber: 'REC-099',
    description: '',
    transactionDate: tDate,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 5, 1),
  );

  setUp(() {
    repository = MockTransactionRepository();
    sut = UpdateTransactionUseCase(repository);
    registerFallbackValue(TransactionType.debit);
    registerFallbackValue(tDate);
  });

  group('UpdateTransactionUseCase', () {
    test('updates and returns the updated entity', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          contactId: tUpdated.contactId,
          generalLedgerId: tUpdated.generalLedgerId,
          amount: 22000,
          gstAmount: 2000,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-099',
          description: '',
          transactionDate: tDate,
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        contactId: tUpdated.contactId,
        generalLedgerId: tUpdated.generalLedgerId,
        amount: 22000,
        gstAmount: 2000,
        transactionType: TransactionType.debit,
        receiptNumber: 'REC-099',
        description: '',
        transactionDate: tDate,
      );

      // Assert
      expect(result, equals(tUpdated));
      expect(result.totalAmount, equals(24000));
    });

    test('throws TransactionValidationException when amount is zero', () {
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 0,
          gstAmount: 0,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          description: '',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('throws TransactionValidationException when gstAmount exceeds amount', () {
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 500,
          gstAmount: 501,
          transactionType: TransactionType.credit,
          receiptNumber: 'REC-001',
          description: '',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('throws TransactionNotFoundException propagated from repository', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: any(named: 'entityId'),
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: any(named: 'transactionType'),
          receiptNumber: any(named: 'receiptNumber'),
          description: any(named: 'description'),
          transactionDate: any(named: 'transactionDate'),
        ),
      ).thenThrow(TransactionNotFoundException(tId));

      // Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 1000,
          gstAmount: 0,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          description: '',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });
  });
}
