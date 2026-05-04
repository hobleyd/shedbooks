import '../entities/gst_rate.dart';

/// Contract for GST rate persistence.
abstract interface class IGstRateRepository {
  /// Creates a new GST rate and returns the persisted entity.
  /// Throws [GstRateDuplicateEffectiveDateException] if [effectiveFrom] is already in use.
  Future<GstRate> create({
    required double rate,
    required DateTime effectiveFrom,
  });

  /// Returns a GST rate by [id], or null if not found / deleted.
  Future<GstRate?> findById(String id);

  /// Returns all active (non-deleted) GST rates, ordered by [effectiveFrom] descending.
  Future<List<GstRate>> findAll();

  /// Returns the rate whose [effectiveFrom] is the highest value on or before [date].
  /// Returns null when no rate has been defined for that date.
  Future<GstRate?> findEffectiveAt(DateTime date);

  /// Updates an existing rate and returns the updated entity.
  /// Throws [GstRateNotFoundException] if [id] does not exist.
  /// Throws [GstRateDuplicateEffectiveDateException] if the new [effectiveFrom] conflicts.
  Future<GstRate> update({
    required String id,
    required double rate,
    required DateTime effectiveFrom,
  });

  /// Soft-deletes the rate with [id].
  /// Throws [GstRateNotFoundException] if [id] does not exist.
  Future<void> delete(String id);
}
