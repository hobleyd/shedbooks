/// A month that has been locked, preventing edits to transactions in that period.
class LockedMonth {
  /// Unique identifier (UUID v4).
  final String id;

  /// The Auth0 organisation ID that owns this lock.
  final String entityId;

  /// The locked period in YYYY-MM format (e.g. `"2026-04"`).
  final String monthYear;

  /// When the lock was applied.
  final DateTime lockedAt;

  const LockedMonth({
    required this.id,
    required this.entityId,
    required this.monthYear,
    required this.lockedAt,
  });
}
