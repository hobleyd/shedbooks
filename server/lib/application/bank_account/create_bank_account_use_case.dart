import '../../domain/entities/bank_account.dart';
import '../../domain/exceptions/bank_account_exception.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Creates a new bank account for an entity.
class CreateBankAccountUseCase {
  final IBankAccountRepository _repository;

  const CreateBankAccountUseCase(this._repository);

  /// Throws [BankAccountValidationException] on invalid input.
  Future<BankAccount> execute({
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  }) async {
    final trimmedBank = bankName.trim();
    final trimmedName = accountName.trim();
    final trimmedBsb = bsb.replaceAll('-', '').trim();
    final trimmedAccNum = accountNumber.trim();
    final trimmedCurrency = currency.trim().toUpperCase();

    if (trimmedBank.isEmpty) {
      throw const BankAccountValidationException('Bank name must not be empty');
    }
    if (trimmedName.isEmpty) {
      throw const BankAccountValidationException(
          'Account name must not be empty');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(trimmedBsb)) {
      throw const BankAccountValidationException('BSB must be exactly 6 digits');
    }
    if (!RegExp(r'^\d{6,10}$').hasMatch(trimmedAccNum)) {
      throw const BankAccountValidationException(
          'Account number must be 6 to 10 digits');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(trimmedCurrency)) {
      throw const BankAccountValidationException(
          'Currency must be a 3-letter ISO code');
    }

    return _repository.create(
      entityId: entityId,
      bankName: trimmedBank,
      accountName: trimmedName,
      bsb: trimmedBsb,
      accountNumber: trimmedAccNum,
      accountType: accountType,
      currency: trimmedCurrency,
    );
  }
}
