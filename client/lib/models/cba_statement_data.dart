/// A single transaction parsed from a CBA bank statement PDF.
class CbaTransactionEntry {
  final String date;
  final String description;
  final int amountCents;
  final bool isDebit;
  final int balanceCents;

  const CbaTransactionEntry({
    required this.date,
    required this.description,
    required this.amountCents,
    required this.isDebit,
    required this.balanceCents,
  });

  factory CbaTransactionEntry.fromJson(Map<String, dynamic> json) =>
      CbaTransactionEntry(
        date: json['date'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        isDebit: json['isDebit'] as bool,
        balanceCents: json['balanceCents'] as int,
      );
}

/// Parsed data from a CBA bank statement PDF.
class CbaStatementData {
  final String accountNumber;
  final String statementPeriod;
  final int openingBalanceCents;
  final int closingBalanceCents;
  final List<CbaTransactionEntry> transactions;

  const CbaStatementData({
    required this.accountNumber,
    required this.statementPeriod,
    required this.openingBalanceCents,
    required this.closingBalanceCents,
    required this.transactions,
  });

  factory CbaStatementData.fromJson(Map<String, dynamic> json) =>
      CbaStatementData(
        accountNumber: json['accountNumber'] as String,
        statementPeriod: json['statementPeriod'] as String,
        openingBalanceCents: json['openingBalanceCents'] as int,
        closingBalanceCents: json['closingBalanceCents'] as int,
        transactions: (json['transactions'] as List<dynamic>)
            .map((t) => CbaTransactionEntry.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
