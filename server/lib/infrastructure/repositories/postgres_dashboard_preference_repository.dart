import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../domain/entities/dashboard_preference.dart';
import '../../domain/repositories/i_dashboard_preference_repository.dart';

/// PostgreSQL implementation of [IDashboardPreferenceRepository].
class PostgresDashboardPreferenceRepository
    implements IDashboardPreferenceRepository {
  final Pool _pool;

  const PostgresDashboardPreferenceRepository(this._pool);

  /// @param entityId - The entity identifier used as the primary key.
  @override
  Future<DashboardPreference?> find(String entityId) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT entity_id, selected_account_pairs FROM dashboard_preferences WHERE entity_id = @entityId',
      ),
      parameters: {'entityId': entityId},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  /// @param preference.entityId - Upsert key.
  /// @param preference.selectedAccountPairs - JSONB array of income/expense GL pairs.
  @override
  Future<void> save(DashboardPreference preference) async {
    final pairsJson = jsonEncode(preference.selectedAccountPairs
        .map((p) => {'incomeGlId': p.incomeGlId, 'expenseGlId': p.expenseGlId})
        .toList());

    await _pool.execute(
      Sql.named('''
        INSERT INTO dashboard_preferences (entity_id, selected_account_pairs)
        VALUES (@entityId, @pairs::jsonb)
        ON CONFLICT (entity_id) DO UPDATE
          SET selected_account_pairs = EXCLUDED.selected_account_pairs
      '''),
      parameters: {
        'entityId': preference.entityId,
        'pairs': pairsJson,
      },
    );
  }

  static DashboardPreference _mapRow(Map<String, dynamic> row) {
    final raw = row['selected_account_pairs'];
    final List<dynamic> list = raw is String ? jsonDecode(raw) : (raw as List);
    final pairs = list.map((e) {
      final m = e as Map<String, dynamic>;
      return GlAccountPair(
        incomeGlId: m['incomeGlId'] as String,
        expenseGlId: m['expenseGlId'] as String,
      );
    }).toList();

    return DashboardPreference(
      entityId: row['entity_id'] as String,
      selectedAccountPairs: pairs,
    );
  }
}
