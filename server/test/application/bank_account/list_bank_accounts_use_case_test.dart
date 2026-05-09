import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/bank_account.dart';
import 'package:shedbooks_server/domain/repositories/i_bank_account_repository.dart';
import 'package:shedbooks_server/application/bank_account/list_bank_accounts_use_case.dart';

class MockBankAccountRepository extends Mock implements IBankAccountRepository {}

void main() {
  late MockBankAccountRepository repository;
  late ListBankAccountsUseCase sut;

  const tEntityId = 'entity-1';

  final tAccounts = [
    BankAccount(
      id: '00000000-0000-0000-0000-000000000001',
      entityId: tEntityId,
      bankName: 'Commonwealth Bank',
      accountName: 'Woodgate Mens Shed',
      bsb: '062000',
      accountNumber: '12345678',
      accountType: BankAccountType.transaction,
      currency: 'AUD',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    BankAccount(
      id: '00000000-0000-0000-0000-000000000002',
      entityId: tEntityId,
      bankName: 'Commonwealth Bank',
      accountName: 'Woodgate Mens Shed Savings',
      bsb: '062000',
      accountNumber: '87654321',
      accountType: BankAccountType.savings,
      currency: 'AUD',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  setUp(() {
    repository = MockBankAccountRepository();
    sut = ListBankAccountsUseCase(repository);
  });

  group('ListBankAccountsUseCase', () {
    test('returns all bank accounts for the entity', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => tAccounts);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result.length, equals(2));
      expect(result.first.bankName, equals('Commonwealth Bank'));
    });

    test('returns empty list when no accounts exist', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
