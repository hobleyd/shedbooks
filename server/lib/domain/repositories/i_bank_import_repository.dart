import '../entities/bank_import.dart';

/// Contract for [BankImport] persistence.
abstract interface class IBankImportRepository {
  /// Returns all import records for [entityId], ordered by process date.
  Future<List<BankImport>> findAll(String entityId);

  /// Bulk-inserts [rows]. Rows whose (entity_id, process_date, description,
  /// amount_cents, is_debit) tuple already exists are silently ignored.
  Future<void> saveAll(List<BankImport> rows);
}
