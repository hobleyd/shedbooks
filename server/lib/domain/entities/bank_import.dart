/// A bank statement row that has been actioned during a CBA import session.
class BankImport {
  final String id;
  final String entityId;

  /// ISO-8601 date string (YYYY-MM-DD) from the bank statement Process Date column.
  final String processDate;

  final String description;
  final int amountCents;
  final bool isDebit;
  final DateTime importedAt;

  const BankImport({
    required this.id,
    required this.entityId,
    required this.processDate,
    required this.description,
    required this.amountCents,
    required this.isDebit,
    required this.importedAt,
  });
}
