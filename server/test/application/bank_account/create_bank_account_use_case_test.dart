import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/bank_account.dart';
import 'package:shedbooks_server/domain/exceptions/bank_account_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_bank_account_repository.dart';
import 'package:shedbooks_server/application/bank_account/create_bank_account_use_case.dart';

class MockBankAccountRepository extends Mock implements IBankAccountRepository {}

void main() {
  late MockBankAccountRepository repository;
  late CreateBankAccountUseCase sut;

  const tEntityId = 'entity-1';
  final tAccount = BankAccount(
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
  );

  setUp(() {
    repository = MockBankAccountRepository();
    sut = CreateBankAccountUseCase(repository);
    registerFallbackValue(BankAccountType.transaction);
  });

  group('CreateBankAccountUseCase', () {
    test('creates and returns a bank account with valid input', () async {
      // Arrange
      when(() => repository.create(
            entityId: any(named: 'entityId'),
            bankName: any(named: 'bankName'),
            accountName: any(named: 'accountName'),
            bsb: any(named: 'bsb'),
            accountNumber: any(named: 'accountNumber'),
            accountType: any(named: 'accountType'),
            currency: any(named: 'currency'),
          )).thenAnswer((_) async => tAccount);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        bankName: 'Commonwealth Bank',
        accountName: 'Woodgate Mens Shed',
        bsb: '062000',
        accountNumber: '12345678',
        accountType: BankAccountType.transaction,
        currency: 'AUD',
      );

      // Assert
      expect(result.bankName, equals('Commonwealth Bank'));
      expect(result.bsb, equals('062000'));
    });

    test('strips dashes from BSB before persisting', () async {
      // Arrange
      when(() => repository.create(
            entityId: any(named: 'entityId'),
            bankName: any(named: 'bankName'),
            accountName: any(named: 'accountName'),
            bsb: '062000',
            accountNumber: any(named: 'accountNumber'),
            accountType: any(named: 'accountType'),
            currency: any(named: 'currency'),
          )).thenAnswer((_) async => tAccount);

      // Act
      await sut.execute(
        entityId: tEntityId,
        bankName: 'Commonwealth Bank',
        accountName: 'Woodgate Mens Shed',
        bsb: '062-000',
        accountNumber: '12345678',
        accountType: BankAccountType.transaction,
        currency: 'AUD',
      );

      // Assert
      verify(() => repository.create(
            entityId: any(named: 'entityId'),
            bankName: any(named: 'bankName'),
            accountName: any(named: 'accountName'),
            bsb: '062000',
            accountNumber: any(named: 'accountNumber'),
            accountType: any(named: 'accountType'),
            currency: any(named: 'currency'),
          )).called(1);
    });

    test('uppercases currency before persisting', () async {
      // Arrange
      when(() => repository.create(
            entityId: any(named: 'entityId'),
            bankName: any(named: 'bankName'),
            accountName: any(named: 'accountName'),
            bsb: any(named: 'bsb'),
            accountNumber: any(named: 'accountNumber'),
            accountType: any(named: 'accountType'),
            currency: 'AUD',
          )).thenAnswer((_) async => tAccount);

      // Act / Assert — should not throw
      await expectLater(
        sut.execute(
          entityId: tEntityId,
          bankName: 'Commonwealth Bank',
          accountName: 'Woodgate Mens Shed',
          bsb: '062000',
          accountNumber: '12345678',
          accountType: BankAccountType.transaction,
          currency: 'aud',
        ),
        completes,
      );
    });

    test('throws BankAccountValidationException when bank name is blank', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          bankName: '  ',
          accountName: 'Woodgate Mens Shed',
          bsb: '062000',
          accountNumber: '12345678',
          accountType: BankAccountType.transaction,
          currency: 'AUD',
        ),
        throwsA(isA<BankAccountValidationException>()),
      );
    });

    test('throws BankAccountValidationException when BSB is not 6 digits', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          bankName: 'Commonwealth Bank',
          accountName: 'Woodgate Mens Shed',
          bsb: '06200',
          accountNumber: '12345678',
          accountType: BankAccountType.transaction,
          currency: 'AUD',
        ),
        throwsA(isA<BankAccountValidationException>()),
      );
    });

    test('throws BankAccountValidationException when account number is too short', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          bankName: 'Commonwealth Bank',
          accountName: 'Woodgate Mens Shed',
          bsb: '062000',
          accountNumber: '12345',
          accountType: BankAccountType.transaction,
          currency: 'AUD',
        ),
        throwsA(isA<BankAccountValidationException>()),
      );
    });

    test('throws BankAccountValidationException when account number is too long', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          bankName: 'Commonwealth Bank',
          accountName: 'Woodgate Mens Shed',
          bsb: '062000',
          accountNumber: '12345678901',
          accountType: BankAccountType.transaction,
          currency: 'AUD',
        ),
        throwsA(isA<BankAccountValidationException>()),
      );
    });

    test('throws BankAccountValidationException when currency is invalid', () {
      expect(
        () => sut.execute(
          entityId: tEntityId,
          bankName: 'Commonwealth Bank',
          accountName: 'Woodgate Mens Shed',
          bsb: '062000',
          accountNumber: '12345678',
          accountType: BankAccountType.transaction,
          currency: 'AU',
        ),
        throwsA(isA<BankAccountValidationException>()),
      );
    });
  });
}
