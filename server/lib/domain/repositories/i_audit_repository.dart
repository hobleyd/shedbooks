import '../entities/audit_entry.dart';

/// Contract for audit log persistence.
abstract interface class IAuditRepository {
  /// Inserts a new audit entry. Failures are non-fatal — callers should swallow errors.
  Future<void> insert(AuditEntry entry);

  /// Returns a page of audit entries for [entityId], newest first.
  ///
  /// [search] is matched case-insensitively against user_email, ip_address,
  /// action, table_name, record_id, path, method, and user_id.
  Future<List<AuditEntry>> findAll({
    required String entityId,
    String? search,
    required int limit,
    required int offset,
  });

  /// Returns the total number of entries matching the same filters as [findAll].
  Future<int> count({required String entityId, String? search});
}
