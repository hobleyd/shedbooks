import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/locked_month_exception.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/update_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}
class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockTransactionRepository repository;
  late MockLockedMonthRepository lockedMonths;
  late UpdateTransactionUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 5, 1);
  const tMonthYear = '2026-05';
  final tExisting = Transaction(
    id: tId,
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
    lockedMonths = MockLockedMonthRepository();
    sut = UpdateTransactionUseCase(repository, lockedMonths);
    registerFallbackValue(TransactionType.debit);
    registerFallbackValue(tDate);
    // Default: transaction exists and month is not locked.
    when(() => repository.findById(tId, entityId: tEntityId))
        .thenAnswer((_) async => tExisting);
    when(() => lockedMonths.isLocked(any(), any())).thenAnswer((_) async => false);
  });

  group('UpdateTransactionUseCase', () {
    test('updates and returns the updated entity (debit stays debit)', () async {
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
      expect(result.transactionType, equals(TransactionType.debit));
      expect(result.totalAmount, equals(24000));
    });

    test('preserves credit (money-in) type when updating a credit transaction', () async {
      // Arrange
      final tCreditExisting = Transaction(
        id: tId,
        contactId: '00000000-0000-0000-0000-000000000002',
        generalLedgerId: '00000000-0000-0000-0000-000000000004',
        amount: 5000,
        gstAmount: 500,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final tCreditUpdated = Transaction(
        id: tId,
        contactId: '00000000-0000-0000-0000-000000000002',
        generalLedgerId: '00000000-0000-0000-0000-000000000004',
        amount: 9000,
        gstAmount: 900,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: 'Updated amount',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );

      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tCreditExisting);
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          contactId: tCreditUpdated.contactId,
          generalLedgerId: tCreditUpdated.generalLedgerId,
          amount: 9000,
          gstAmount: 900,
          transactionType: TransactionType.credit,
          receiptNumber: 'Bank Transfer',
          description: 'Updated amount',
          transactionDate: tDate,
        ),
      ).thenAnswer((_) async => tCreditUpdated);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        contactId: tCreditUpdated.contactId,
        generalLedgerId: tCreditUpdated.generalLedgerId,
        amount: 9000,
        gstAmount: 900,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: 'Updated amount',
        transactionDate: tDate,
      );

      // Assert — credit must not silently flip to debit
      expect(result.transactionType, equals(TransactionType.credit));
      expect(result.totalAmount, equals(9900));
    });

    test('can change transaction type from money-out (debit) to money-in (credit)', () async {
      // Arrange — user reclassifies a debit transaction to a money-in GL account
      final tReclassified = Transaction(
        id: tId,
        contactId: '00000000-0000-0000-0000-000000000002',
        generalLedgerId: '00000000-0000-0000-0000-000000000004',
        amount: 11000,
        gstAmount: 1000,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );

      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: TransactionType.credit,
          receiptNumber: any(named: 'receiptNumber'),
          description: any(named: 'description'),
          transactionDate: any(named: 'transactionDate'),
        ),
      ).thenAnswer((_) async => tReclassified);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        contactId: tExisting.contactId,
        generalLedgerId: '00000000-0000-0000-0000-000000000004',
        amount: 11000,
        gstAmount: 1000,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: '',
        transactionDate: tDate,
      );

      // Assert
      expect(result.transactionType, equals(TransactionType.credit));
    });

    test('can change transaction type from money-in (credit) to money-out (debit)', () async {
      // Arrange — user reclassifies a credit transaction to a money-out GL account
      final tCreditExisting = Transaction(
        id: tId,
        contactId: '00000000-0000-0000-0000-000000000002',
        generalLedgerId: '00000000-0000-0000-0000-000000000004',
        amount: 5000,
        gstAmount: 0,
        transactionType: TransactionType.credit,
        receiptNumber: 'Bank Transfer',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final tReclassified = Transaction(
        id: tId,
        contactId: '00000000-0000-0000-0000-000000000002',
        generalLedgerId: '00000000-0000-0000-0000-000000000003',
        amount: 5000,
        gstAmount: 0,
        transactionType: TransactionType.debit,
        receiptNumber: 'P-26001',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );

      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tCreditExisting);
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          contactId: any(named: 'contactId'),
          generalLedgerId: any(named: 'generalLedgerId'),
          amount: any(named: 'amount'),
          gstAmount: any(named: 'gstAmount'),
          transactionType: TransactionType.debit,
          receiptNumber: any(named: 'receiptNumber'),
          description: any(named: 'description'),
          transactionDate: any(named: 'transactionDate'),
        ),
      ).thenAnswer((_) async => tReclassified);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        contactId: tCreditExisting.contactId,
        generalLedgerId: '00000000-0000-0000-0000-000000000003',
        amount: 5000,
        gstAmount: 0,
        transactionType: TransactionType.debit,
        receiptNumber: 'P-26001',
        description: '',
        transactionDate: tDate,
      );

      // Assert — credit must not silently flip to debit
      expect(result.transactionType, equals(TransactionType.debit));
    });

    test('throws MonthIsLockedException when existing transaction month is locked',
        () async {
      // Arrange
      when(() => lockedMonths.isLocked(tEntityId, tMonthYear))
          .thenAnswer((_) async => true);

      // Act / Assert
      await expectLater(
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
        throwsA(isA<MonthIsLockedException>()),
      );
    });

    test('throws TransactionNotFoundException when transaction does not exist',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      await expectLater(
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
  });
}
