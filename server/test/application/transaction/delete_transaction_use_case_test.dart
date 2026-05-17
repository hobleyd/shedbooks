import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/locked_month_exception.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/delete_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}
class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockTransactionRepository repository;
  late MockLockedMonthRepository lockedMonths;
  late DeleteTransactionUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tTransaction = Transaction(
    id: tId,
    contactId: '00000000-0000-0000-0000-000000000002',
    generalLedgerId: '00000000-0000-0000-0000-000000000003',
    amount: 3300,
    gstAmount: 300,
    transactionType: TransactionType.debit,
    receiptNumber: 'REC-003',
    description: '',
    transactionDate: DateTime.utc(2026, 2, 28),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  const tMonthYear = '2026-02';

  setUp(() {
    repository = MockTransactionRepository();
    lockedMonths = MockLockedMonthRepository();
    sut = DeleteTransactionUseCase(repository, lockedMonths);
    // Default: transaction exists and month is not locked.
    when(() => repository.findById(tId, entityId: tEntityId))
        .thenAnswer((_) async => tTransaction);
    when(() => lockedMonths.isLocked(any(), any())).thenAnswer((_) async => false);
  });

  group('DeleteTransactionUseCase', () {
    test('calls repository delete when transaction exists and month is unlocked',
        () async {
      // Arrange
      when(
        () => repository.delete(tId, entityId: tEntityId),
      ).thenAnswer((_) async {});

      // Act
      await sut.execute(tId, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(tId, entityId: tEntityId)).called(1);
    });

    test('throws MonthIsLockedException when transaction month is locked', () async {
      // Arrange
      when(() => lockedMonths.isLocked(tEntityId, tMonthYear))
          .thenAnswer((_) async => true);

      // Act / Assert
      await expectLater(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<MonthIsLockedException>()),
      );
      verifyNever(
          () => repository.delete(any(), entityId: any(named: 'entityId')));
    });

    test('throws TransactionNotFoundException when transaction does not exist',
        () async {
      // Arrange
      when(
        () => repository.findById(tId, entityId: tEntityId),
      ).thenAnswer((_) async => null);

      // Act / Assert
      await expectLater(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<TransactionNotFoundException>()),
      );
      verifyNever(
          () => repository.delete(any(), entityId: any(named: 'entityId')));
    });
  });
}
