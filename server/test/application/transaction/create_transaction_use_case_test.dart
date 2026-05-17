import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/locked_month_exception.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/create_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}
class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockTransactionRepository repository;
  late MockLockedMonthRepository lockedMonths;
  late CreateTransactionUseCase sut;

  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 5, 1);
  const tMonthYear = '2026-05';
  final tTransaction = Transaction(
    id: '00000000-0000-0000-0000-000000000001',
    contactId: '00000000-0000-0000-0000-000000000002',
    generalLedgerId: '00000000-0000-0000-0000-000000000003',
    amount: 11000,
    gstAmount: 1000,
    transactionType: TransactionType.debit,
    receiptNumber: 'REC-001',
    description: '',
    transactionDate: tDate,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockTransactionRepository();
    lockedMonths = MockLockedMonthRepository();
    sut = CreateTransactionUseCase(repository, lockedMonths);
    registerFallbackValue(TransactionType.debit);
    registerFallbackValue(tDate);
    // Default: month is not locked.
    when(() => lockedMonths.isLocked(any(), any())).thenAnswer((_) async => false);
  });

  group('CreateTransactionUseCase', () {
    test('creates a money-out (debit) transaction and returns the persisted entity', () async {
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
          description: '',
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
        description: '',
        transactionDate: tDate,
      );

      // Assert
      expect(result, equals(tTransaction));
      expect(result.transactionType, equals(TransactionType.debit));
      expect(result.totalAmount, equals(12000));
    });

    test('creates a money-in (credit) transaction and returns the persisted entity', () async {
      // Arrange
      final tCreditTransaction = Transaction(
        id: '00000000-0000-0000-0000-000000000001',
        contactId: '00000000-0000-0000-0000-000000000002',
        generalLedgerId: '00000000-0000-0000-0000-000000000005',
        amount: 20000,
        gstAmount: 2000,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      when(
        () => repository.create(
          entityId: tEntityId,
          contactId: tCreditTransaction.contactId,
          generalLedgerId: tCreditTransaction.generalLedgerId,
          amount: 20000,
          gstAmount: 2000,
          transactionType: TransactionType.credit,
          receiptNumber: 'Bank Transfer',
          description: '',
          transactionDate: tDate,
        ),
      ).thenAnswer((_) async => tCreditTransaction);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        contactId: tCreditTransaction.contactId,
        generalLedgerId: tCreditTransaction.generalLedgerId,
        amount: 20000,
        gstAmount: 2000,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: '',
        transactionDate: tDate,
      );

      // Assert — credit (money-in) must not be silently changed to debit
      expect(result.transactionType, equals(TransactionType.credit));
      expect(result.totalAmount, equals(22000));
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
          description: any(named: 'description'),
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
        description: '',
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
          description: any(named: 'description'),
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
        description: '',
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
          description: any(named: 'description'),
          transactionDate: any(named: 'transactionDate'),
        ),
      ).called(1);
    });

    test('throws MonthIsLockedException when month is locked', () async {
      // Arrange
      when(() => lockedMonths.isLocked(tEntityId, tMonthYear))
          .thenAnswer((_) async => true);

      // Act / Assert
      await expectLater(
        () => sut.execute(
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
        throwsA(isA<MonthIsLockedException>()),
      );
      verifyNever(() => repository.create(
            entityId: any(named: 'entityId'),
            contactId: any(named: 'contactId'),
            generalLedgerId: any(named: 'generalLedgerId'),
            amount: any(named: 'amount'),
            gstAmount: any(named: 'gstAmount'),
            transactionType: any(named: 'transactionType'),
            receiptNumber: any(named: 'receiptNumber'),
            description: any(named: 'description'),
            transactionDate: any(named: 'transactionDate'),
          ));
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
          description: '',
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
          description: '',
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
          description: '',
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
          description: '',
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
          description: '',
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
          description: any(named: 'description'),
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
          description: '',
          transactionDate: tDate,
        ),
        completes,
      );
    });
  });
}
