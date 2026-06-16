// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
