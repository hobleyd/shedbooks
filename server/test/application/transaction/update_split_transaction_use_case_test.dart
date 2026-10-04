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
import 'package:shedbooks_server/domain/entities/transaction_line.dart';
import 'package:shedbooks_server/domain/exceptions/locked_month_exception.dart';
import 'package:shedbooks_server/domain/exceptions/transaction_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/update_split_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}
class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockTransactionRepository repository;
  late MockLockedMonthRepository lockedMonths;
  late UpdateSplitTransactionUseCase sut;

  const tEntityId = 'entity-1';
  const tContactId = '00000000-0000-0000-0000-000000000002';
  const tGlA = '00000000-0000-0000-0000-00000000000a';
  const tGlB = '00000000-0000-0000-0000-00000000000b';
  const tGroupId = 'group-1';
  final tDate = DateTime.utc(2026, 5, 1);
  const tLines = [
    TransactionLine(generalLedgerId: tGlA, amount: 10000, gstAmount: 1000),
    TransactionLine(generalLedgerId: tGlB, amount: 5000, gstAmount: 0),
  ];

  Transaction row(
    String id, {
    String? splitGroupId,
    int? splitLineNo,
    bool bankMatched = false,
    bool isCash = false,
    String? abaBatchName,
    String? bankAccountId,
  }) =>
      Transaction(
        id: id,
        contactId: tContactId,
        generalLedgerId: tGlA,
        amount: 10000,
        gstAmount: 1000,
        transactionType: TransactionType.debit,
        receiptNumber: 'P-26001',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        splitGroupId: splitGroupId,
        splitLineNo: splitLineNo,
        bankMatched: bankMatched,
        isCash: isCash,
        abaBatchName: abaBatchName,
        bankAccountId: bankAccountId,
      );

  void stubReplace(List<Transaction> result) {
    when(
      () => repository.replaceWithLines(
        replacedIds: any(named: 'replacedIds'),
        entityId: any(named: 'entityId'),
        contactId: any(named: 'contactId'),
        transactionType: any(named: 'transactionType'),
        receiptNumber: any(named: 'receiptNumber'),
        paymentReference: any(named: 'paymentReference'),
        transactionDate: any(named: 'transactionDate'),
        isCash: any(named: 'isCash'),
        bankMatched: any(named: 'bankMatched'),
        abaBatchName: any(named: 'abaBatchName'),
        bankAccountId: any(named: 'bankAccountId'),
        lines: any(named: 'lines'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Verifies the single replaceWithLines call, matching each named argument
  /// that is supplied and accepting anything for those that are not.
  void verifyReplaced({
    List<String>? replacedIds,
    int? lineCount,
    bool? isCash,
    bool? bankMatched,
    String? abaBatchName,
    String? bankAccountId,
  }) {
    verify(
      () => repository.replaceWithLines(
        replacedIds: any(named: 'replacedIds', that: replacedIds == null ? anything : equals(replacedIds)),
        entityId: tEntityId,
        contactId: tContactId,
        transactionType: TransactionType.debit,
        receiptNumber: 'P-26001',
        paymentReference: any(named: 'paymentReference'),
        transactionDate: any(named: 'transactionDate'),
        isCash: any(named: 'isCash', that: isCash == null ? anything : equals(isCash)),
        bankMatched: any(named: 'bankMatched', that: bankMatched == null ? anything : equals(bankMatched)),
        abaBatchName: any(named: 'abaBatchName', that: abaBatchName == null ? anything : equals(abaBatchName)),
        bankAccountId: any(named: 'bankAccountId', that: bankAccountId == null ? anything : equals(bankAccountId)),
        lines: any(named: 'lines', that: lineCount == null ? anything : hasLength(lineCount)),
      ),
    ).called(1);
  }

  void verifyNeverReplaced() {
    verifyNever(
      () => repository.replaceWithLines(
        replacedIds: any(named: 'replacedIds'),
        entityId: any(named: 'entityId'),
        contactId: any(named: 'contactId'),
        transactionType: any(named: 'transactionType'),
        receiptNumber: any(named: 'receiptNumber'),
        paymentReference: any(named: 'paymentReference'),
        transactionDate: any(named: 'transactionDate'),
        isCash: any(named: 'isCash'),
        bankMatched: any(named: 'bankMatched'),
        abaBatchName: any(named: 'abaBatchName'),
        bankAccountId: any(named: 'bankAccountId'),
        lines: any(named: 'lines'),
      ),
    );
  }

  Future<SplitUpdateResult> act(
    String id, {
    List<TransactionLine> lines = tLines,
    DateTime? transactionDate,
    bool? isCash,
    String? bankAccountId,
  }) =>
      sut.execute(
        id: id,
        entityId: tEntityId,
        contactId: tContactId,
        transactionType: TransactionType.debit,
        receiptNumber: 'P-26001',
        transactionDate: transactionDate ?? tDate,
        isCash: isCash,
        bankAccountId: bankAccountId,
        lines: lines,
      );

  setUp(() {
    repository = MockTransactionRepository();
    lockedMonths = MockLockedMonthRepository();
    sut = UpdateSplitTransactionUseCase(repository, lockedMonths);
    registerFallbackValue(TransactionType.debit);
    registerFallbackValue(tDate);
    registerFallbackValue(<TransactionLine>[]);
    registerFallbackValue(<String>[]);
    // Default: month is not locked.
    when(() => lockedMonths.isLocked(any(), any())).thenAnswer((_) async => false);
  });

  group('UpdateSplitTransactionUseCase', () {
    test('converts an ordinary transaction into a split, replacing only that row', () async {
      // Arrange
      final existing = row('id-1');
      final after = [
        row('new-1', splitGroupId: 'g', splitLineNo: 1),
        row('new-2', splitGroupId: 'g', splitLineNo: 2),
      ];
      when(() => repository.findById('id-1', entityId: tEntityId))
          .thenAnswer((_) async => existing);
      stubReplace(after);

      // Act
      final result = await act('id-1');

      // Assert
      expect(result.before, equals([existing]));
      expect(result.after, equals(after));
      verifyReplaced(replacedIds: ['id-1'], lineCount: 2);
      verifyNever(() => repository.findBySplitGroup(any(), entityId: any(named: 'entityId')));
    });

    test('replaces every line of the split when editing one of its lines', () async {
      // Arrange
      final group = [
        row('id-1', splitGroupId: tGroupId, splitLineNo: 1),
        row('id-2', splitGroupId: tGroupId, splitLineNo: 2),
        row('id-3', splitGroupId: tGroupId, splitLineNo: 3),
      ];
      when(() => repository.findById('id-2', entityId: tEntityId))
          .thenAnswer((_) async => group[1]);
      when(() => repository.findBySplitGroup(tGroupId, entityId: tEntityId))
          .thenAnswer((_) async => group);
      stubReplace([]);

      // Act
      final result = await act('id-2');

      // Assert
      expect(result.before, equals(group));
      verifyReplaced(replacedIds: ['id-1', 'id-2', 'id-3']);
    });

    test('accepts a single line, collapsing the split to an ordinary transaction', () async {
      // Arrange
      final group = [
        row('id-1', splitGroupId: tGroupId, splitLineNo: 1),
        row('id-2', splitGroupId: tGroupId, splitLineNo: 2),
      ];
      when(() => repository.findById('id-1', entityId: tEntityId))
          .thenAnswer((_) async => group.first);
      when(() => repository.findBySplitGroup(tGroupId, entityId: tEntityId))
          .thenAnswer((_) async => group);
      stubReplace([row('new-1')]);

      // Act
      final result = await act('id-1', lines: [tLines.first]);

      // Assert
      expect(result.after.single.isSplit, isFalse);
      verifyReplaced(lineCount: 1);
    });

    test('carries bank-matched state, ABA batch and bank account over to the new rows', () async {
      // Arrange
      final group = [
        row('id-1', splitGroupId: tGroupId, splitLineNo: 1, bankMatched: true,
            abaBatchName: 'WMS260501001', bankAccountId: 'bank-1'),
        row('id-2', splitGroupId: tGroupId, splitLineNo: 2, bankMatched: true,
            abaBatchName: 'WMS260501001', bankAccountId: 'bank-1'),
      ];
      when(() => repository.findById('id-1', entityId: tEntityId))
          .thenAnswer((_) async => group.first);
      when(() => repository.findBySplitGroup(tGroupId, entityId: tEntityId))
          .thenAnswer((_) async => group);
      stubReplace([]);

      // Act
      await act('id-1');

      // Assert
      verifyReplaced(
        isCash: false,
        bankMatched: true,
        abaBatchName: 'WMS260501001',
        bankAccountId: 'bank-1',
      );
    });

    test('marks the new rows bank-matched when the transaction becomes cash', () async {
      // Arrange
      when(() => repository.findById('id-1', entityId: tEntityId))
          .thenAnswer((_) async => row('id-1'));
      stubReplace([]);

      // Act
      await act('id-1', isCash: true, bankAccountId: 'cash-1');

      // Assert
      verifyReplaced(isCash: true, bankMatched: true, bankAccountId: 'cash-1');
    });

    test('throws TransactionNotFoundException when the transaction does not exist', () async {
      // Arrange
      when(() => repository.findById('missing', entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      await expectLater(
        () => act('missing'),
        throwsA(isA<TransactionNotFoundException>()),
      );
      verifyNeverReplaced();
    });

    test('throws TransactionValidationException when no lines are given', () async {
      // Act / Assert
      await expectLater(
        () => act('id-1', lines: const []),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverReplaced();
    });

    test('throws MonthIsLockedException when the existing month is locked', () async {
      // Arrange
      when(() => repository.findById('id-1', entityId: tEntityId))
          .thenAnswer((_) async => row('id-1'));
      when(() => lockedMonths.isLocked(tEntityId, '2026-05'))
          .thenAnswer((_) async => true);

      // Act / Assert
      await expectLater(() => act('id-1'), throwsA(isA<MonthIsLockedException>()));
      verifyNeverReplaced();
    });

    test('throws MonthIsLockedException when moving into a locked month', () async {
      // Arrange
      when(() => repository.findById('id-1', entityId: tEntityId))
          .thenAnswer((_) async => row('id-1'));
      when(() => lockedMonths.isLocked(tEntityId, '2026-06'))
          .thenAnswer((_) async => true);

      // Act / Assert
      await expectLater(
        () => act('id-1', transactionDate: DateTime.utc(2026, 6, 2)),
        throwsA(isA<MonthIsLockedException>()),
      );
      verifyNeverReplaced();
    });
  });
}
