/// A closing bank balance record for a given bank account and statement period.
class ClosingBankBalance {
  final String id;
  final String entityId;
  final String bankAccountId;

  /// Last day of the statement period (ISO date string, e.g. "2026-04-30").
  final String balanceDate;

  /// Closing balance in cents (positive = credit).
  final int balanceCents;

  /// Human-readable statement period, e.g. "1 Apr 2026 - 30 Apr 2026".
  final String statementPeriod;

  final DateTime createdAt;

  const ClosingBankBalance({
    required this.id,
    required this.entityId,
    required this.bankAccountId,
    required this.balanceDate,
    required this.balanceCents,
    required this.statementPeriod,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityId': entityId,
        'bankAccountId': bankAccountId,
        'balanceDate': balanceDate,
        'balanceCents': balanceCents,
        'statementPeriod': statementPeriod,
        'createdAt': createdAt.toIso8601String(),
      };
}
