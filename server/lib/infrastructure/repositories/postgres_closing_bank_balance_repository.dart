import 'package:postgres/postgres.dart';

import '../../domain/entities/closing_bank_balance.dart';
import '../../domain/repositories/i_closing_bank_balance_repository.dart';

/// PostgreSQL implementation of [IClosingBankBalanceRepository].
class PostgresClosingBankBalanceRepository
    implements IClosingBankBalanceRepository {
  final Pool _pool;

  const PostgresClosingBankBalanceRepository(this._pool);

  static const _cols =
      'id::text, entity_id, bank_account_id::text, balance_date::text, '
      'balance_cents, statement_period, created_at';

  @override
  Future<ClosingBankBalance> save({
    required String entityId,
    required String bankAccountId,
    required String balanceDate,
    required int balanceCents,
    required String statementPeriod,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO closing_bank_balances
          (entity_id, bank_account_id, balance_date, balance_cents, statement_period)
        VALUES
          (@entityId, @bankAccountId::uuid, @balanceDate::date, @balanceCents, @statementPeriod)
        ON CONFLICT (entity_id, bank_account_id, balance_date) DO UPDATE SET
          balance_cents    = EXCLUDED.balance_cents,
          statement_period = EXCLUDED.statement_period,
          created_at       = NOW()
        RETURNING $_cols
      '''),
      parameters: {
        'entityId': entityId,
        'bankAccountId': bankAccountId,
        'balanceDate': balanceDate,
        'balanceCents': balanceCents,
        'statementPeriod': statementPeriod,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<ClosingBankBalance>> findByBankAccount({
    required String entityId,
    required String bankAccountId,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols
        FROM closing_bank_balances
        WHERE entity_id = @entityId AND bank_account_id = @bankAccountId::uuid
        ORDER BY balance_date DESC
      '''),
      parameters: {'entityId': entityId, 'bankAccountId': bankAccountId},
    );
    return result.map((r) => _mapRow(r.toColumnMap())).toList();
  }

  static ClosingBankBalance _mapRow(Map<String, dynamic> cols) =>
      ClosingBankBalance(
        id: cols['id'] as String,
        entityId: cols['entity_id'] as String,
        bankAccountId: cols['bank_account_id'] as String,
        balanceDate: cols['balance_date'] as String,
        balanceCents: cols['balance_cents'] as int,
        statementPeriod: cols['statement_period'] as String,
        createdAt: cols['created_at'] as DateTime,
      );
}
