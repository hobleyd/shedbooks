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
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/list_transactions_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late ListTransactionsUseCase sut;

  const tEntityId = 'entity-1';
  final tTransactions = [
    Transaction(
      id: '00000000-0000-0000-0000-000000000001',
      contactId: '00000000-0000-0000-0000-000000000010',
      generalLedgerId: '00000000-0000-0000-0000-000000000020',
      amount: 11000,
      gstAmount: 1000,
      transactionType: TransactionType.debit,
      receiptNumber: 'REC-001',
      description: '',
      transactionDate: DateTime.utc(2026, 5, 1),
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
    ),
    Transaction(
      id: '00000000-0000-0000-0000-000000000002',
      contactId: '00000000-0000-0000-0000-000000000010',
      generalLedgerId: '00000000-0000-0000-0000-000000000020',
      amount: 5500,
      gstAmount: 500,
      transactionType: TransactionType.credit,
      receiptNumber: 'REC-002',
      description: '',
      transactionDate: DateTime.utc(2026, 4, 15),
      createdAt: DateTime.utc(2026, 4, 15),
      updatedAt: DateTime.utc(2026, 4, 15),
    ),
  ];

  setUp(() {
    repository = MockTransactionRepository();
    sut = ListTransactionsUseCase(repository);
  });

  group('ListTransactionsUseCase', () {
    test('returns all active transactions from repository', () async {
      // Arrange
      when(
        () => repository.findAll(entityId: tEntityId),
      ).thenAnswer((_) async => tTransactions);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tTransactions));
      verify(() => repository.findAll(entityId: tEntityId)).called(1);
    });

    test('each transaction exposes correct totalAmount', () async {
      // Arrange
      when(
        () => repository.findAll(entityId: tEntityId),
      ).thenAnswer((_) async => tTransactions);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result[0].totalAmount, equals(12000));
      expect(result[1].totalAmount, equals(6000));
    });

    test('returns empty list when no transactions exist', () async {
      // Arrange
      when(
        () => repository.findAll(entityId: tEntityId),
      ).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
