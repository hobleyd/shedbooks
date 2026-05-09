import '../entities/general_ledger.dart';

/// Contract for general ledger persistence.
abstract interface class IGeneralLedgerRepository {
  /// Creates a new general ledger account and returns the persisted entity.
  Future<GeneralLedger> create({
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
  });

  /// Returns a general ledger account by [id] within [entityId], or null if not found / deleted.
  Future<GeneralLedger?> findById(String id, {required String entityId});

  /// Returns all active (non-deleted) general ledger accounts for [entityId].
  Future<List<GeneralLedger>> findAll({required String entityId});

  /// Updates an existing account and returns the updated entity.
  /// Throws [GeneralLedgerNotFoundException] if [id] does not exist within [entityId].
  Future<GeneralLedger> update({
    required String id,
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
  });

  /// Soft-deletes the account with [id] within [entityId].
  /// Throws [GeneralLedgerNotFoundException] if [id] does not exist within [entityId].
  Future<void> delete(String id, {required String entityId});
}
