import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/transaction.dart';
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/list_transactions_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late ListTransactionsUseCase sut;

  final tTransactions = [
    Transaction(
      id: '00000000-0000-0000-0000-000000000001',
      contactId: '00000000-0000-0000-0000-000000000010',
      generalLedgerId: '00000000-0000-0000-0000-000000000020',
      amount: 11000,
      gstAmount: 1000,
      transactionType: TransactionType.debit,
      receiptNumber: 'REC-001',
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
      when(() => repository.findAll()).thenAnswer((_) async => tTransactions);

      // Act
      final result = await sut.execute();

      // Assert
      expect(result, equals(tTransactions));
      verify(() => repository.findAll()).called(1);
    });

    test('returns empty list when no transactions exist', () async {
      // Arrange
      when(() => repository.findAll()).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute();

      // Assert
      expect(result, isEmpty);
    });
  });
}
