/// A month that has been locked against transaction edits for a specific bank account.
class LockedMonthEntry {
  /// The locked period in YYYY-MM format (e.g. `"2026-04"`).
  final String monthYear;

  /// The bank account this lock applies to.
  final String bankAccountId;

  /// When the lock was applied.
  final DateTime lockedAt;

  const LockedMonthEntry({
    required this.monthYear,
    required this.bankAccountId,
    required this.lockedAt,
  });

  factory LockedMonthEntry.fromJson(Map<String, dynamic> json) =>
      LockedMonthEntry(
        monthYear: json['monthYear'] as String,
        bankAccountId: json['bankAccountId'] as String,
        lockedAt: DateTime.parse(json['lockedAt'] as String),
      );
}
