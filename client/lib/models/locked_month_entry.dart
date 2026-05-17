/// A month that has been locked against transaction edits.
class LockedMonthEntry {
  /// The locked period in YYYY-MM format (e.g. `"2026-04"`).
  final String monthYear;

  /// When the lock was applied.
  final DateTime lockedAt;

  const LockedMonthEntry({
    required this.monthYear,
    required this.lockedAt,
  });

  factory LockedMonthEntry.fromJson(Map<String, dynamic> json) =>
      LockedMonthEntry(
        monthYear: json['monthYear'] as String,
        lockedAt: DateTime.parse(json['lockedAt'] as String),
      );

  /// YYYY-MM prefix derived from [monthYear] — same value, used for comparison.
  String get prefix => monthYear;
}
