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
        SELECT entity_id, name, abn, incorporation_identifier,
               money_in_receipt_format, money_out_receipt_format,
               created_at, updated_at
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
        INSERT INTO entity_details
          (entity_id, name, abn, incorporation_identifier,
           money_in_receipt_format, money_out_receipt_format)
        VALUES
          (@entityId, @name, @abn, @incorporationIdentifier,
           @moneyInReceiptFormat, @moneyOutReceiptFormat)
        ON CONFLICT (entity_id) DO UPDATE
          SET name                     = EXCLUDED.name,
              abn                      = EXCLUDED.abn,
              incorporation_identifier = EXCLUDED.incorporation_identifier,
              money_in_receipt_format  = EXCLUDED.money_in_receipt_format,
              money_out_receipt_format = EXCLUDED.money_out_receipt_format,
              updated_at               = NOW()
        RETURNING entity_id, name, abn, incorporation_identifier,
                  money_in_receipt_format, money_out_receipt_format,
                  created_at, updated_at
      '''),
      parameters: {
        'entityId': details.entityId,
        'name': details.name,
        'abn': details.abn,
        'incorporationIdentifier': details.incorporationIdentifier,
        'moneyInReceiptFormat': details.moneyInReceiptFormat,
        'moneyOutReceiptFormat': details.moneyOutReceiptFormat,
      },
    );

    return _mapRow(result.first.toColumnMap());
  }

  static EntityDetails _mapRow(Map<String, dynamic> row) => EntityDetails(
        entityId: row['entity_id'] as String,
        name: row['name'] as String,
        abn: (row['abn'] as String).trim(),
        incorporationIdentifier: row['incorporation_identifier'] as String,
        moneyInReceiptFormat: (row['money_in_receipt_format'] as String?) ?? '',
        moneyOutReceiptFormat: (row['money_out_receipt_format'] as String?) ?? '',
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );
}
