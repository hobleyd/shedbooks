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
        'SELECT entity_id, selected_gl_ids FROM dashboard_preferences WHERE entity_id = @entityId',
      ),
      parameters: {'entityId': entityId},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  /// @param preference.entityId - Upsert key.
  /// @param preference.selectedGlIds - Array of GL account UUIDs.
  @override
  Future<void> save(DashboardPreference preference) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO dashboard_preferences (entity_id, selected_gl_ids)
        VALUES (@entityId, @selectedGlIds)
        ON CONFLICT (entity_id) DO UPDATE
          SET selected_gl_ids = EXCLUDED.selected_gl_ids
      '''),
      parameters: {
        'entityId': preference.entityId,
        'selectedGlIds': preference.selectedGlIds,
      },
    );
  }

  static DashboardPreference _mapRow(Map<String, dynamic> row) {
    final raw = row['selected_gl_ids'];
    final ids = (raw as List).cast<String>();
    return DashboardPreference(
      entityId: row['entity_id'] as String,
      selectedGlIds: ids,
    );
  }
}
