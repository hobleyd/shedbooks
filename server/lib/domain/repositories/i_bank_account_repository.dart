import '../entities/bank_account.dart';

/// Repository interface for bank account persistence.
abstract class IBankAccountRepository {
  Future<BankAccount> create({
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  });

  Future<BankAccount?> findById(String id, {required String entityId});

  Future<List<BankAccount>> findAll({required String entityId});

  Future<BankAccount> update({
    required String id,
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  });

  Future<void> delete(String id, {required String entityId});
}
