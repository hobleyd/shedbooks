import '../entities/general_ledger.dart';

/// Contract for general ledger persistence.
abstract interface class IGeneralLedgerRepository {
  /// Creates a new general ledger account and returns the persisted entity.
  Future<GeneralLedger> create({
    required String label,
    required String description,
    required bool gstApplicable,
  });

  /// Returns a general ledger account by [id], or null if not found / deleted.
  Future<GeneralLedger?> findById(String id);

  /// Returns all active (non-deleted) general ledger accounts.
  Future<List<GeneralLedger>> findAll();

  /// Updates an existing account and returns the updated entity.
  /// Throws [GeneralLedgerNotFoundException] if [id] does not exist.
  Future<GeneralLedger> update({
    required String id,
    required String label,
    required String description,
    required bool gstApplicable,
  });

  /// Soft-deletes the account with [id].
  /// Throws [GeneralLedgerNotFoundException] if [id] does not exist.
  Future<void> delete(String id);
}
