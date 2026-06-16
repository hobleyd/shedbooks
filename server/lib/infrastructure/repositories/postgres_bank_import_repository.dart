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

import 'package:postgres/postgres.dart';

import '../../domain/entities/bank_import.dart';
import '../../domain/repositories/i_bank_import_repository.dart';

/// PostgreSQL implementation of [IBankImportRepository].
class PostgresBankImportRepository implements IBankImportRepository {
  final Pool _pool;

  const PostgresBankImportRepository(this._pool);

  @override
  Future<List<BankImport>> findAll(String entityId) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id::text, entity_id, process_date::text, description,
               amount_cents, is_debit, imported_at
        FROM bank_imports
        WHERE entity_id = @entityId
        ORDER BY process_date, imported_at
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map(_mapRow).toList();
  }

  @override
  Future<void> saveAll(List<BankImport> rows) async {
    if (rows.isEmpty) return;
    for (final row in rows) {
      await _pool.execute(
        Sql.named('''
          INSERT INTO bank_imports
            (entity_id, process_date, description, amount_cents, is_debit)
          VALUES
            (@entityId, @processDate::date, @description, @amountCents, @isDebit)
          ON CONFLICT DO NOTHING
        '''),
        parameters: {
          'entityId': row.entityId,
          'processDate': row.processDate,
          'description': row.description,
          'amountCents': row.amountCents,
          'isDebit': row.isDebit,
        },
      );
    }
  }

  static BankImport _mapRow(ResultRow row) {
    final cols = row.toColumnMap();
    return BankImport(
      id: cols['id'] as String,
      entityId: cols['entity_id'] as String,
      processDate: cols['process_date'] as String,
      description: cols['description'] as String,
      amountCents: cols['amount_cents'] as int,
      isDebit: cols['is_debit'] as bool,
      importedAt: cols['imported_at'] as DateTime,
    );
  }
}
