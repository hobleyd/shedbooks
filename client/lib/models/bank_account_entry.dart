/// The type of bank account.
enum BankAccountType { transaction, savings, termDeposit }

/// A bank account returned from the API.
class BankAccountEntry {
  final String id;
  final String bankName;
  final String accountName;
  final String bsb;
  final String accountNumber;
  final BankAccountType accountType;
  final String currency;

  const BankAccountEntry({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
    required this.accountType,
    required this.currency,
  });

  factory BankAccountEntry.fromJson(Map<String, dynamic> json) =>
      BankAccountEntry(
        id: json['id'] as String,
        bankName: json['bankName'] as String,
        accountName: json['accountName'] as String,
        bsb: json['bsb'] as String,
        accountNumber: json['accountNumber'] as String,
        accountType: switch (json['accountType'] as String) {
          'savings' => BankAccountType.savings,
          'termDeposit' => BankAccountType.termDeposit,
          _ => BankAccountType.transaction,
        },
        currency: json['currency'] as String,
      );

  /// BSB formatted as XXX-XXX for display.
  String get bsbFormatted =>
      bsb.length == 6 ? '${bsb.substring(0, 3)}-${bsb.substring(3)}' : bsb;

  String get accountTypeLabel => switch (accountType) {
        BankAccountType.transaction => 'Transaction',
        BankAccountType.savings => 'Savings',
        BankAccountType.termDeposit => 'Term Deposit',
      };
}
