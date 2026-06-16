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
