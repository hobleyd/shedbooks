// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/exceptions/locked_month_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/bank_match_transactions_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}
class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockTransactionRepository repository;
  late MockLockedMonthRepository lockedMonths;
  late BankMatchTransactionsUseCase sut;

  const tEntityId = 'entity-1';
  const tBankAccountId = '00000000-0000-0000-0000-0000000000aa';
  const tId1 = '00000000-0000-0000-0000-000000000001';
  const tId2 = '00000000-0000-0000-0000-000000000002';
  const tIds = [tId1, tId2];

  Transaction tx({required String id, required DateTime date}) => Transaction(
        id: id,
        contactId: '00000000-0000-0000-0000-000000000003',
        generalLedgerId: '00000000-0000-0000-0000-000000000004',
        amount: 5000,
        gstAmount: 0,
        transactionType: TransactionType.credit,
        receiptNumber: 'REC-001',
        description: '',
        transactionDate: date,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  setUp(() {
    repository = MockTransactionRepository();
    lockedMonths = MockLockedMonthRepository();
    sut = BankMatchTransactionsUseCase(repository, lockedMonths);
    when(() => repository.bankMatch(
          any(),
          entityId: any(named: 'entityId'),
          bankAccountId: any(named: 'bankAccountId'),
          transactionDate: any(named: 'transactionDate'),
        )).thenAnswer((_) async {});
    when(() => lockedMonths.isLocked(any(), any())).thenAnswer((_) async => false);
  });

  group('BankMatchTransactionsUseCase', () {
    test('calls bankMatch on repository with ids, entityId and bankAccountId', () async {
      await sut.execute(
        ids: tIds,
        entityId: tEntityId,
        bankAccountId: tBankAccountId,
      );

      verify(() => repository.bankMatch(
            tIds,
            entityId: tEntityId,
            bankAccountId: tBankAccountId,
            transactionDate: null,
          )).called(1);
    });

    test('passes null bankAccountId through unchanged when not provided', () async {
      await sut.execute(ids: tIds, entityId: tEntityId);

      verify(() => repository.bankMatch(
            tIds,
            entityId: tEntityId,
            bankAccountId: null,
            transactionDate: null,
          )).called(1);
    });

    test('does not consult the locked-month repository when no transactionDate is given', () async {
      await sut.execute(ids: tIds, entityId: tEntityId, bankAccountId: tBankAccountId);

      verifyNever(() => repository.findById(any(), entityId: any(named: 'entityId')));
      verifyNever(() => lockedMonths.isLocked(any(), any()));
    });

    test('does nothing when ids list is empty', () async {
      await sut.execute(
        ids: const [],
        entityId: tEntityId,
        bankAccountId: tBankAccountId,
      );

      verifyNever(() => repository.bankMatch(
            any(),
            entityId: any(named: 'entityId'),
            bankAccountId: any(named: 'bankAccountId'),
            transactionDate: any(named: 'transactionDate'),
          ));
    });

    group('with a transactionDate (manual match date stamping)', () {
      final tDate = DateTime.utc(2026, 8, 15);

      test('passes transactionDate through to the repository when neither month is locked', () async {
        when(() => repository.findById(tId1, entityId: tEntityId))
            .thenAnswer((_) async => tx(id: tId1, date: DateTime.utc(2026, 8, 1)));
        when(() => repository.findById(tId2, entityId: tEntityId))
            .thenAnswer((_) async => tx(id: tId2, date: DateTime.utc(2026, 8, 10)));

        await sut.execute(
          ids: tIds,
          entityId: tEntityId,
          bankAccountId: tBankAccountId,
          transactionDate: tDate,
        );

        verify(() => repository.bankMatch(
              tIds,
              entityId: tEntityId,
              bankAccountId: tBankAccountId,
              transactionDate: tDate,
            )).called(1);
      });

      test('throws MonthIsLockedException and does not call bankMatch when the '
          "transaction's existing month is locked", () async {
        when(() => repository.findById(tId1, entityId: tEntityId))
            .thenAnswer((_) async => tx(id: tId1, date: DateTime.utc(2026, 7, 20)));
        when(() => lockedMonths.isLocked(tEntityId, '2026-07')).thenAnswer((_) async => true);

        await expectLater(
          () => sut.execute(
            ids: [tId1],
            entityId: tEntityId,
            bankAccountId: tBankAccountId,
            transactionDate: tDate,
          ),
          throwsA(isA<MonthIsLockedException>()),
        );
      });

      test('throws MonthIsLockedException when the target month (transactionDate) is locked', () async {
        when(() => repository.findById(tId1, entityId: tEntityId))
            .thenAnswer((_) async => tx(id: tId1, date: DateTime.utc(2026, 7, 20)));
        when(() => lockedMonths.isLocked(tEntityId, '2026-08')).thenAnswer((_) async => true);

        await expectLater(
          () => sut.execute(
            ids: [tId1],
            entityId: tEntityId,
            bankAccountId: tBankAccountId,
            transactionDate: tDate,
          ),
          throwsA(isA<MonthIsLockedException>()),
        );
      });

      test('skips ids that no longer exist rather than throwing', () async {
        when(() => repository.findById(tId1, entityId: tEntityId))
            .thenAnswer((_) async => null);

        await sut.execute(
          ids: [tId1],
          entityId: tEntityId,
          bankAccountId: tBankAccountId,
          transactionDate: tDate,
        );

        verify(() => repository.bankMatch(
              [tId1],
              entityId: tEntityId,
              bankAccountId: tBankAccountId,
              transactionDate: tDate,
            )).called(1);
      });
    });
  });
}
