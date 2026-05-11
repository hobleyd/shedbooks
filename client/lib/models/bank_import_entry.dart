/// A bank statement row previously actioned during an import session.
class BankImportEntry {
  final String processDate;
  final String description;
  final int amountCents;
  final bool isDebit;

  const BankImportEntry({
    required this.processDate,
    required this.description,
    required this.amountCents,
    required this.isDebit,
  });

  factory BankImportEntry.fromJson(Map<String, dynamic> json) =>
      BankImportEntry(
        processDate: json['processDate'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        isDebit: json['isDebit'] as bool,
      );

  /// Key used for O(1) deduplication lookups.
  String get dedupKey => '$processDate\x00${isDebit ? 1 : 0}\x00$amountCents\x00$description';
}
