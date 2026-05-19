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
    final result = await _pool.execute(
      Sql.named('''
        SELECT 1 FROM locked_months
        WHERE entity_id = @entityId AND month_year = @monthYear
        LIMIT 1
      '''),
      parameters: {'entityId': entityId, 'monthYear': monthYear},
    );
    return result.isNotEmpty;
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
