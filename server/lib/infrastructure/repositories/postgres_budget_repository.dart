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
import 'package:uuid/uuid.dart';

import '../../domain/entities/budget_gl_mapping.dart';
import '../../domain/entities/budget_line.dart';
import '../../domain/exceptions/budget_exception.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// PostgreSQL implementation of [IBudgetRepository].
class PostgresBudgetRepository implements IBudgetRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresBudgetRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  @override
  Future<List<int>> listYears({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT year FROM budgets
        WHERE entity_id = @entityId
        ORDER BY year ASC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((r) => r.toColumnMap()['year'] as int).toList();
  }

  @override
  Future<List<BudgetLine>> getLines(int year, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT bl.general_ledger_id, bl.month, bl.amount_cents
        FROM budget_lines bl
        JOIN budgets b ON b.id = bl.budget_id
        WHERE b.entity_id = @entityId
          AND b.year = @year
        ORDER BY bl.general_ledger_id, bl.month
      '''),
      parameters: {'entityId': entityId, 'year': year},
    );

    return result.map((row) {
      final m = row.toColumnMap();
      return BudgetLine(
        generalLedgerId: m['general_ledger_id'].toString(),
        month: m['month'] as int,
        amountCents: m['amount_cents'] as int,
      );
    }).toList();
  }

  @override
  Future<void> saveLines(
    int year,
    List<BudgetLine> lines, {
    required String entityId,
  }) async {
    await _pool.runTx((TxSession tx) async {
      // Upsert the budget record.
      final budgetResult = await tx.execute(
        Sql.named('''
          INSERT INTO budgets (id, entity_id, year)
          VALUES (@id::uuid, @entityId, @year)
          ON CONFLICT (entity_id, year)
          DO UPDATE SET updated_at = NOW()
          RETURNING id
        '''),
        parameters: {
          'id': _uuid.v4(),
          'entityId': entityId,
          'year': year,
        },
      );
      final budgetId = budgetResult.first.toColumnMap()['id'].toString();

      // Delete existing lines then bulk-insert new ones.
      await tx.execute(
        Sql.named('DELETE FROM budget_lines WHERE budget_id = @budgetId::uuid'),
        parameters: {'budgetId': budgetId},
      );

      for (final line in lines) {
        try {
          await tx.execute(
            Sql.named('''
              INSERT INTO budget_lines (id, budget_id, general_ledger_id, month, amount_cents)
              VALUES (@id::uuid, @budgetId::uuid, @glId::uuid, @month, @amountCents)
            '''),
            parameters: {
              'id': _uuid.v4(),
              'budgetId': budgetId,
              'glId': line.generalLedgerId,
              'month': line.month,
              'amountCents': line.amountCents,
            },
          );
        } on ServerException catch (e) {
          if (e.code == '23505') {
            throw const BudgetValidationException(
              'Duplicate budget entry: the same GL account appears more than once for the same month.',
            );
          }
          rethrow;
        }
      }
    });
  }

  @override
  Future<void> delete(int year, {required String entityId}) async {
    // budget_lines cascade on DELETE of budgets.
    await _pool.execute(
      Sql.named('''
        DELETE FROM budgets
        WHERE entity_id = @entityId AND year = @year
      '''),
      parameters: {'entityId': entityId, 'year': year},
    );
  }

  @override
  Future<List<BudgetGlMapping>> getMappings({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT entity_id, external_code, external_name, general_ledger_id
        FROM budget_gl_mappings
        WHERE entity_id = @entityId
        ORDER BY external_code
      '''),
      parameters: {'entityId': entityId},
    );

    return result.map((row) {
      final m = row.toColumnMap();
      return BudgetGlMapping(
        entityId: m['entity_id'] as String,
        externalCode: m['external_code'] as String,
        externalName: m['external_name'] as String,
        generalLedgerId: m['general_ledger_id'].toString(),
      );
    }).toList();
  }

  @override
  Future<void> saveMappings(
    List<BudgetGlMapping> mappings, {
    required String entityId,
  }) async {
    await _pool.runTx((TxSession tx) async {
      await tx.execute(
        Sql.named(
          'DELETE FROM budget_gl_mappings WHERE entity_id = @entityId',
        ),
        parameters: {'entityId': entityId},
      );

      for (final mapping in mappings) {
        await tx.execute(
          Sql.named('''
            INSERT INTO budget_gl_mappings
              (id, entity_id, external_code, external_name, general_ledger_id)
            VALUES (@id::uuid, @entityId, @code, @name, @glId::uuid)
          '''),
          parameters: {
            'id': _uuid.v4(),
            'entityId': entityId,
            'code': mapping.externalCode,
            'name': mapping.externalName,
            'glId': mapping.generalLedgerId,
          },
        );
      }
    });
  }
}
