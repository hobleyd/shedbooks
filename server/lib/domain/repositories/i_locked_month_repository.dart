import '../entities/locked_month.dart';

/// Contract for [LockedMonth] persistence.
abstract interface class ILockedMonthRepository {
  /// Returns all locked months for [entityId], ordered by month_year descending.
  Future<List<LockedMonth>> findAll(String entityId);

  /// Returns `true` if [monthYear] (YYYY-MM) is locked for [entityId].
  Future<bool> isLocked(String entityId, String monthYear);

  /// Locks [monthYear] for [entityId]. Idempotent — no error if already locked.
  Future<void> lock(String entityId, String monthYear);

  /// Unlocks [monthYear] for [entityId]. No-op if not currently locked.
  Future<void> unlock(String entityId, String monthYear);
}
