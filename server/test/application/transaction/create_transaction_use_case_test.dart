import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/create_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late CreateTransactionUseCase sut;

  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 5, 1);
  final tTransaction = Transaction(
    id: '00000000-0000-0000-0000-000000000001',
    contactId: '00000000-0000-0000-0000-000000000002',
    generalLedgerId: '00000000-0000-0000-0000-000000000003',
    amount: 11000,
    gstAmount: 1000,
    transactionType: TransactionType.debit,
    receiptNumber: 'REC-001',
    transactionDate: tDate,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockTransactionRepository();
    sut = CreateTransactionUseCase(repository);
    registerFallbackValue(TransactionType.debit);
    registerFallbackValue(tDate);
  });

  group('CreateTransactionUseCase', () {
    test('creates a transaction and returns the persisted entity', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          contactId: tTransaction.contactId,
          generalLedgerId: tTransaction.generalLedgerId,
          amount: 11000,
          gstAmount: 1000,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          transactionDate: tDate,
        ),
      ).thenAnswer((_) async => tTransaction);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        contactId: tTransaction.contactId,
        generalLedgerId: tTransaction.generalLedgerId,
        amount: 11000,
        gstAmount: 1000,
        transactionType: TransactionType.debit,
        receiptNumber: 'REC-001',
        transactionDate: tDate,
      );

      // Assert
      expect(result, equals(tTransaction));
      expect(result.totalAmount, equals(12000));
    });

    test('totalAmount equals amount plus gstAmount', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: any(named: 'entityId'),
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: any(named: 'transactionType'),
          receiptNumber: any(named: 'receiptNumber'),
          transactionDate: any(named: 'transactionDate'),
        ),
      ).thenAnswer((_) async => tTransaction);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        contactId: 'c1',
        generalLedgerId: 'g1',
        amount: 11000,
        gstAmount: 1000,
        transactionType: TransactionType.debit,
        receiptNumber: 'REC-001',
        transactionDate: tDate,
      );

      // Assert
      expect(result.totalAmount, equals(result.amount + result.gstAmount));
    });

    test('trims whitespace from receiptNumber before persisting', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: any(named: 'entityId'),
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: any(named: 'transactionType'),
          receiptNumber: 'REC-001',
          transactionDate: any(named: 'transactionDate'),
        ),
      ).thenAnswer((_) async => tTransaction);

      // Act
      await sut.execute(
        entityId: tEntityId,
        contactId: tTransaction.contactId,
        generalLedgerId: tTransaction.generalLedgerId,
        amount: 11000,
        gstAmount: 1000,
        transactionType: TransactionType.debit,
        receiptNumber: '  REC-001  ',
        transactionDate: tDate,
      );

      // Assert
      verify(
        () => repository.create(
          entityId: any(named: 'entityId'),
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: any(named: 'transactionType'),
          receiptNumber: 'REC-001',
          transactionDate: any(named: 'transactionDate'),
        ),
      ).called(1);
    });

    test('throws TransactionValidationException when amount is zero', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 0,
          gstAmount: 0,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('throws TransactionValidationException when amount is negative', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: -100,
          gstAmount: 0,
          transactionType: TransactionType.credit,
          receiptNumber: 'REC-001',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('throws TransactionValidationException when gstAmount is negative', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 11000,
          gstAmount: -1,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('throws TransactionValidationException when gstAmount exceeds amount', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 1000,
          gstAmount: 1001,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('throws TransactionValidationException when receiptNumber is empty', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 1000,
          gstAmount: 0,
          transactionType: TransactionType.credit,
          receiptNumber: '   ',
          transactionDate: tDate,
        ),
        throwsA(isA<TransactionValidationException>()),
      );
    });

    test('allows gstAmount equal to amount', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: any(named: 'entityId'),
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: any(named: 'transactionType'),
          receiptNumber: any(named: 'receiptNumber'),
          transactionDate: any(named: 'transactionDate'),
        ),
      ).thenAnswer((_) async => tTransaction);

      // Act / Assert — should not throw
      await expectLater(
        sut.execute(
          entityId: tEntityId,
          contactId: 'c1',
          generalLedgerId: 'g1',
          amount: 1000,
          gstAmount: 1000,
          transactionType: TransactionType.debit,
          receiptNumber: 'REC-001',
          transactionDate: tDate,
        ),
        completes,
      );
    });
  });
}
