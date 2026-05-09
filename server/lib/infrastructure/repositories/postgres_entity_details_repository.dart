import 'package:postgres/postgres.dart';

import '../../domain/entities/entity_details.dart';
import '../../domain/repositories/i_entity_details_repository.dart';

/// PostgreSQL implementation of [IEntityDetailsRepository].
class PostgresEntityDetailsRepository implements IEntityDetailsRepository {
  final Pool _pool;

  const PostgresEntityDetailsRepository(this._pool);

  /// @param entityId - Primary key used to look up the record.
  @override
  Future<EntityDetails?> find(String entityId) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT entity_id, name, abn, incorporation_identifier, created_at, updated_at
        FROM entity_details
        WHERE entity_id = @entityId
      '''),
      parameters: {'entityId': entityId},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  /// @param details.entityId - Upsert key.
  /// @param details.abn - Stored as CHAR(11); must be exactly 11 digits.
  @override
  Future<EntityDetails> save(EntityDetails details) async {
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO entity_details (entity_id, name, abn, incorporation_identifier)
        VALUES (@entityId, @name, @abn, @incorporationIdentifier)
        ON CONFLICT (entity_id) DO UPDATE
          SET name                     = EXCLUDED.name,
              abn                      = EXCLUDED.abn,
              incorporation_identifier = EXCLUDED.incorporation_identifier,
              updated_at               = NOW()
        RETURNING entity_id, name, abn, incorporation_identifier, created_at, updated_at
      '''),
      parameters: {
        'entityId': details.entityId,
        'name': details.name,
        'abn': details.abn,
        'incorporationIdentifier': details.incorporationIdentifier,
      },
    );

    return _mapRow(result.first.toColumnMap());
  }

  static EntityDetails _mapRow(Map<String, dynamic> row) => EntityDetails(
        entityId: row['entity_id'] as String,
        name: row['name'] as String,
        abn: (row['abn'] as String).trim(),
        incorporationIdentifier: row['incorporation_identifier'] as String,
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );
}
