import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/gst_rate.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// PostgreSQL implementation of [IGstRateRepository].
class PostgresGstRateRepository implements IGstRateRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresGstRateRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  @override
  Future<GstRate> create({
    required String entityId,
    required double rate,
    required DateTime effectiveFrom,
  }) async {
    try {
      final id = _uuid.v4();
      final result = await _pool.execute(
        Sql.named('''
          INSERT INTO gst_rates (id, entity_id, rate, effective_from)
          VALUES (@id::uuid, @entityId, @rate, @effectiveFrom::date)
          RETURNING id, rate, effective_from, created_at, updated_at, deleted_at
        '''),
        parameters: {
          'id': id,
          'entityId': entityId,
          'rate': rate,
          'effectiveFrom': effectiveFrom.toIso8601String().substring(0, 10),
        },
      );
      return _mapRow(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == '23505') {
        throw GstRateDuplicateEffectiveDateException(effectiveFrom);
      }
      rethrow;
    }
  }

  @override
  Future<GstRate?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, rate, effective_from, created_at, updated_at, deleted_at
        FROM gst_rates
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<GstRate>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, rate, effective_from, created_at, updated_at, deleted_at
        FROM gst_rates
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY effective_from DESC
      '''),
      parameters: {'entityId': entityId},
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<GstRate?> findEffectiveAt(DateTime date, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, rate, effective_from, created_at, updated_at, deleted_at
        FROM gst_rates
        WHERE entity_id = @entityId
          AND effective_from <= @date::date
          AND deleted_at IS NULL
        ORDER BY effective_from DESC
        LIMIT 1
      '''),
      parameters: {
        'entityId': entityId,
        'date': date.toIso8601String().substring(0, 10),
      },
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<GstRate> update({
    required String id,
    required String entityId,
    required double rate,
    required DateTime effectiveFrom,
  }) async {
    try {
      final result = await _pool.execute(
        Sql.named('''
          UPDATE gst_rates
          SET rate           = @rate,
              effective_from = @effectiveFrom::date,
              updated_at     = NOW()
          WHERE id = @id::uuid
            AND entity_id = @entityId
            AND deleted_at IS NULL
          RETURNING id, rate, effective_from, created_at, updated_at, deleted_at
        '''),
        parameters: {
          'id': id,
          'entityId': entityId,
          'rate': rate,
          'effectiveFrom': effectiveFrom.toIso8601String().substring(0, 10),
        },
      );

      if (result.isEmpty) throw GstRateNotFoundException(id);
      return _mapRow(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == '23505') {
        throw GstRateDuplicateEffectiveDateException(effectiveFrom);
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE gst_rates
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.affectedRows == 0) throw GstRateNotFoundException(id);
  }

  GstRate _mapRow(Map<String, dynamic> row) {
    final effectiveFrom = row['effective_from'] as DateTime;

    return GstRate(
      id: row['id'].toString(),
      rate: double.parse(row['rate'].toString()),
      effectiveFrom: DateTime.utc(
        effectiveFrom.year,
        effectiveFrom.month,
        effectiveFrom.day,
      ),
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }
}
