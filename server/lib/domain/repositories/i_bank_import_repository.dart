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

import '../entities/bank_import.dart';

/// Contract for [BankImport] persistence.
abstract interface class IBankImportRepository {
  /// Returns all import records for [entityId], ordered by process date.
  Future<List<BankImport>> findAll(String entityId);

  /// Bulk-inserts [rows]. Rows whose (entity_id, process_date, description,
  /// amount_cents, is_debit) tuple already exists are silently ignored.
  Future<void> saveAll(List<BankImport> rows);
}
