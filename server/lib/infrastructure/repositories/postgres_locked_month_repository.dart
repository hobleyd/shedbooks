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

import '../../domain/entities/locked_month.dart';
import '../../domain/repositories/i_locked_month_repository.dart';

/// PostgreSQL implementation of [ILockedMonthRepository].
class PostgresLockedMonthRepository implements ILockedMonthRepository {
  final Pool _pool;

  const PostgresLockedMonthRepository(this._pool);

  @override
  Future<List<LockedMonth>> findAll(String entityId) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id::text, entity_id, bank_account_id::text, month_year, locked_at
        FROM locked_months
        WHERE entity_id = @entityId
        ORDER BY month_year DESC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map(_mapRow).toList();
  }

  @override
  Future<bool> isLocked(String entityId, String monthYear) async {
    // Blocked only when every active bank account has the month locked.
    final result = await _pool.execute(
      Sql.named('''
        SELECT (
          EXISTS (
            SELECT 1 FROM bank_accounts
            WHERE entity_id = @entityId AND deleted_at IS NULL
          )
          AND NOT EXISTS (
            SELECT 1 FROM bank_accounts ba
            WHERE ba.entity_id = @entityId
              AND ba.deleted_at IS NULL
              AND NOT EXISTS (
                SELECT 1 FROM locked_months lm
                WHERE lm.entity_id = @entityId
                  AND lm.month_year = @monthYear
                  AND lm.bank_account_id = ba.id
              )
          )
        ) AS is_locked
      '''),
      parameters: {'entityId': entityId, 'monthYear': monthYear},
    );
    return (result.first.toColumnMap()['is_locked'] as bool?) ?? false;
  }

  @override
  Future<void> lock(
      String entityId, String monthYear, String bankAccountId) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO locked_months (entity_id, bank_account_id, month_year)
        VALUES (@entityId, @bankAccountId::uuid, @monthYear)
        ON CONFLICT DO NOTHING
      '''),
      parameters: {
        'entityId': entityId,
        'bankAccountId': bankAccountId,
        'monthYear': monthYear,
      },
    );
  }

  @override
  Future<void> unlock(
      String entityId, String monthYear, String bankAccountId) async {
    await _pool.execute(
      Sql.named('''
        DELETE FROM locked_months
        WHERE entity_id = @entityId
          AND month_year = @monthYear
          AND bank_account_id = @bankAccountId::uuid
      '''),
      parameters: {
        'entityId': entityId,
        'monthYear': monthYear,
        'bankAccountId': bankAccountId,
      },
    );
  }

  static LockedMonth _mapRow(ResultRow row) {
    final cols = row.toColumnMap();
    return LockedMonth(
      id: cols['id'] as String,
      entityId: cols['entity_id'] as String,
      bankAccountId: cols['bank_account_id'] as String,
      monthYear: cols['month_year'] as String,
      lockedAt: cols['locked_at'] as DateTime,
    );
  }
}
