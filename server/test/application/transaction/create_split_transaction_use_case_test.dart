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
import 'package:shedbooks_server/application/transaction/_transaction_validator.dart';
import 'package:shedbooks_server/application/transaction/create_split_transaction_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}
class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockTransactionRepository repository;
  late MockLockedMonthRepository lockedMonths;
  late CreateSplitTransactionUseCase sut;

  const tEntityId = 'entity-1';
  const tContactId = '00000000-0000-0000-0000-000000000002';
  const tGlA = '00000000-0000-0000-0000-00000000000a';
  const tGlB = '00000000-0000-0000-0000-00000000000b';
  final tDate = DateTime.utc(2026, 5, 1);
  const tMonthYear = '2026-05';
  const tLines = [
    TransactionLine(generalLedgerId: tGlA, amount: 10000, gstAmount: 1000, description: ' Timber '),
    TransactionLine(generalLedgerId: tGlB, amount: 5000, gstAmount: 0),
  ];

  Transaction row(String id, String glId, int amount, int gst, int lineNo) => Transaction(
        id: id,
        contactId: tContactId,
        generalLedgerId: glId,
        amount: amount,
        gstAmount: gst,
        transactionType: TransactionType.debit,
        receiptNumber: 'P-26001',
        description: '',
        transactionDate: tDate,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        splitGroupId: 'group-1',
        splitLineNo: lineNo,
      );

  void stubCreateSplit(List<Transaction> result) {
    when(
      () => repository.createSplit(
        entityId: any(named: 'entityId'),
        contactId: any(named: 'contactId'),
        transactionType: any(named: 'transactionType'),
        receiptNumber: any(named: 'receiptNumber'),
        paymentReference: any(named: 'paymentReference'),
        transactionDate: any(named: 'transactionDate'),
        isCash: any(named: 'isCash'),
        bankAccountId: any(named: 'bankAccountId'),
        lines: any(named: 'lines'),
      ),
    ).thenAnswer((_) async => result);
  }

  void verifyNeverCreated() {
    verifyNever(
      () => repository.createSplit(
        entityId: any(named: 'entityId'),
        contactId: any(named: 'contactId'),
        transactionType: any(named: 'transactionType'),
        receiptNumber: any(named: 'receiptNumber'),
        paymentReference: any(named: 'paymentReference'),
        transactionDate: any(named: 'transactionDate'),
        isCash: any(named: 'isCash'),
        bankAccountId: any(named: 'bankAccountId'),
        lines: any(named: 'lines'),
      ),
    );
  }

  Future<List<Transaction>> act({
    List<TransactionLine> lines = tLines,
    String receiptNumber = ' P-26001 ',
    String? paymentReference,
  }) =>
      sut.execute(
        entityId: tEntityId,
        contactId: tContactId,
        transactionType: TransactionType.debit,
        receiptNumber: receiptNumber,
        paymentReference: paymentReference,
        transactionDate: tDate,
        lines: lines,
      );

  setUp(() {
    repository = MockTransactionRepository();
    lockedMonths = MockLockedMonthRepository();
    sut = CreateSplitTransactionUseCase(repository, lockedMonths);
    registerFallbackValue(TransactionType.debit);
    registerFallbackValue(tDate);
    registerFallbackValue(<TransactionLine>[]);
    // Default: month is not locked.
    when(() => lockedMonths.isLocked(any(), any())).thenAnswer((_) async => false);
  });

  group('CreateSplitTransactionUseCase', () {
    test('persists every line in one repository call and returns the created rows', () async {
      // Arrange
      final tRows = [
        row('id-1', tGlA, 10000, 1000, 1),
        row('id-2', tGlB, 5000, 0, 2),
      ];
      stubCreateSplit(tRows);

      // Act
      final result = await act(paymentReference: '  ');

      // Assert
      expect(result, equals(tRows));
      final captured = verify(
        () => repository.createSplit(
          entityId: tEntityId,
          contactId: tContactId,
          transactionType: TransactionType.debit,
          receiptNumber: 'P-26001',
          paymentReference: null,
          transactionDate: tDate,
          isCash: false,
          bankAccountId: null,
          lines: captureAny(named: 'lines'),
        ),
      ).captured.single as List<TransactionLine>;
      expect(captured.map((l) => l.generalLedgerId), equals([tGlA, tGlB]));
      expect(captured.map((l) => l.amount), equals([10000, 5000]));
      expect(captured.map((l) => l.gstAmount), equals([1000, 0]));
      expect(captured.first.description, equals('Timber'));
    });

    test('throws TransactionValidationException when fewer than two lines are given', () async {
      // Arrange
      final oneLine = [tLines.first];

      // Act / Assert
      await expectLater(
        () => act(lines: oneLine),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverCreated();
    });

    test('throws TransactionValidationException when there are too many lines', () async {
      // Arrange
      final tooMany = List<TransactionLine>.filled(
        TransactionValidator.maxSplitLines + 1,
        tLines.first,
      );

      // Act / Assert
      await expectLater(
        () => act(lines: tooMany),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverCreated();
    });

    test('throws TransactionValidationException when any line has a non-positive amount', () async {
      // Arrange
      const lines = [
        TransactionLine(generalLedgerId: tGlA, amount: 10000, gstAmount: 0),
        TransactionLine(generalLedgerId: tGlB, amount: 0, gstAmount: 0),
      ];

      // Act / Assert
      await expectLater(
        () => act(lines: lines),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverCreated();
    });

    test('throws TransactionValidationException when a line GST exceeds its amount', () async {
      // Arrange
      const lines = [
        TransactionLine(generalLedgerId: tGlA, amount: 10000, gstAmount: 0),
        TransactionLine(generalLedgerId: tGlB, amount: 100, gstAmount: 101),
      ];

      // Act / Assert
      await expectLater(
        () => act(lines: lines),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverCreated();
    });

    test('throws TransactionValidationException when a line has no general ledger account', () async {
      // Arrange
      const lines = [
        TransactionLine(generalLedgerId: tGlA, amount: 10000, gstAmount: 0),
        TransactionLine(generalLedgerId: ' ', amount: 100, gstAmount: 0),
      ];

      // Act / Assert
      await expectLater(
        () => act(lines: lines),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverCreated();
    });

    test('throws TransactionValidationException when the receipt number is empty', () async {
      // Act / Assert
      await expectLater(
        () => act(receiptNumber: '  '),
        throwsA(isA<TransactionValidationException>()),
      );
      verifyNeverCreated();
    });

    test('throws MonthIsLockedException when the transaction month is locked', () async {
      // Arrange
      when(() => lockedMonths.isLocked(tEntityId, tMonthYear))
          .thenAnswer((_) async => true);

      // Act / Assert
      await expectLater(() => act(), throwsA(isA<MonthIsLockedException>()));
      verifyNeverCreated();
    });
  });
}
