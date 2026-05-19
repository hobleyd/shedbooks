import '../entities/locked_month.dart';

/// Contract for [LockedMonth] persistence.
abstract interface class ILockedMonthRepository {
  /// Returns all locked months for [entityId], ordered by month_year descending.
  Future<List<LockedMonth>> findAll(String entityId);

  /// Returns `true` if [monthYear] (YYYY-MM) is locked for any bank account
  /// belonging to [entityId].
  Future<bool> isLocked(String entityId, String monthYear);

  /// Locks [monthYear] for [bankAccountId] within [entityId]. Idempotent.
  Future<void> lock(String entityId, String monthYear, String bankAccountId);

  /// Unlocks [monthYear] for [bankAccountId] within [entityId]. No-op if not locked.
  Future<void> unlock(String entityId, String monthYear, String bankAccountId);
}
