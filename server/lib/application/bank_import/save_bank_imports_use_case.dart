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

import '../../domain/entities/bank_import.dart';
import '../../domain/repositories/i_bank_import_repository.dart';

/// Records bank statement rows that were actioned during an import session.
class SaveBankImportsUseCase {
  final IBankImportRepository _repository;

  const SaveBankImportsUseCase(this._repository);

  /// Saves [rows] for [entityId]. Duplicate rows (same key tuple) are ignored.
  Future<void> execute({
    required String entityId,
    required List<({String processDate, String description, int amountCents, bool isDebit})> rows,
  }) async {
    if (rows.isEmpty) return;
    final entities = rows
        .map((r) => BankImport(
              id: '',
              entityId: entityId,
              processDate: r.processDate,
              description: r.description,
              amountCents: r.amountCents,
              isDebit: r.isDebit,
              importedAt: DateTime.now(),
            ))
        .toList();
    await _repository.saveAll(entities);
  }
}
