/// A closing bank balance record returned by the server.
class ClosingBankBalanceEntry {
  final String id;
  final String bankAccountId;
  final String balanceDate;
  final int balanceCents;
  final String statementPeriod;
  final DateTime createdAt;

  const ClosingBankBalanceEntry({
    required this.id,
    required this.bankAccountId,
    required this.balanceDate,
    required this.balanceCents,
    required this.statementPeriod,
    required this.createdAt,
  });

  factory ClosingBankBalanceEntry.fromJson(Map<String, dynamic> json) =>
      ClosingBankBalanceEntry(
        id: json['id'] as String,
        bankAccountId: json['bankAccountId'] as String,
        balanceDate: json['balanceDate'] as String,
        balanceCents: json['balanceCents'] as int,
        statementPeriod: json['statementPeriod'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
