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
