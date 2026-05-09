/// The type of bank account.
enum BankAccountType { transaction, savings, termDeposit }

/// A bank account held by the entity.
class BankAccount {
  final String id;
  final String entityId;
  final String bankName;
  final String accountName;
  final String bsb;
  final String accountNumber;
  final BankAccountType accountType;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BankAccount({
    required this.id,
    required this.entityId,
    required this.bankName,
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
    required this.accountType,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });
}
