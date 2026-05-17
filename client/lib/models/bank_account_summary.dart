/// Minimal bank account representation used for dropdown selection.
class BankAccountSummary {
  final String id;
  final String accountName;

  const BankAccountSummary({required this.id, required this.accountName});

  factory BankAccountSummary.fromJson(Map<String, dynamic> json) =>
      BankAccountSummary(
        id: json['id'] as String,
        accountName: json['accountName'] as String,
      );
}
