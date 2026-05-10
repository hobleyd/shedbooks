import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/i_audit_repository.dart';

/// Returns a paginated, optionally filtered page of audit log entries.
class ListAuditEntriesUseCase {
  static const pageSize = 100;

  final IAuditRepository _repository;

  const ListAuditEntriesUseCase(this._repository);

  Future<({List<AuditEntry> entries, int total, int page})> execute({
    required String entityId,
    String? search,
    int page = 1,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final offset = (safePage - 1) * pageSize;
    final trimmedSearch = search?.trim().isEmpty == true ? null : search?.trim();

    final entries = await _repository.findAll(
      entityId: entityId,
      search: trimmedSearch,
      limit: pageSize,
      offset: offset,
    );
    final total = await _repository.count(
      entityId: entityId,
      search: trimmedSearch,
    );

    return (entries: entries, total: total, page: safePage);
  }
}
