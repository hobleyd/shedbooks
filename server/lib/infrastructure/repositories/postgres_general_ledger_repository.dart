import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/general_ledger.dart';
import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// PostgreSQL implementation of [IGeneralLedgerRepository].
class PostgresGeneralLedgerRepository implements IGeneralLedgerRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresGeneralLedgerRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  @override
  Future<GeneralLedger> create({
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
  }) async {
    final id = _uuid.v4();

    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO general_ledger (id, entity_id, label, description, gst_applicable, direction)
        VALUES (@id::uuid, @entityId, @label, @description, @gstApplicable, @direction::gl_direction)
        RETURNING id, label, description, gst_applicable, direction::text, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'label': label,
        'description': description,
        'gstApplicable': gstApplicable,
        'direction': _directionToDb(direction),
      },
    );

    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<GeneralLedger?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, label, description, gst_applicable, direction::text, created_at, updated_at, deleted_at
        FROM general_ledger
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
  Future<List<GeneralLedger>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, label, description, gst_applicable, direction::text, created_at, updated_at, deleted_at
        FROM general_ledger
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY label ASC
      '''),
      parameters: {'entityId': entityId},
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<GeneralLedger> update({
    required String id,
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE general_ledger
        SET label          = @label,
            description    = @description,
            gst_applicable = @gstApplicable,
            direction      = @direction::gl_direction,
            updated_at     = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
        RETURNING id, label, description, gst_applicable, direction::text, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'label': label,
        'description': description,
        'gstApplicable': gstApplicable,
        'direction': _directionToDb(direction),
      },
    );

    if (result.isEmpty) throw GeneralLedgerNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE general_ledger
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.affectedRows == 0) throw GeneralLedgerNotFoundException(id);
  }

  GeneralLedger _mapRow(Map<String, dynamic> row) {
    return GeneralLedger(
      id: row['id'].toString(),
      label: row['label'] as String,
      description: row['description'] as String,
      gstApplicable: row['gst_applicable'] as bool,
      direction: _directionFromDb(row['direction'] as String),
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }

  static String _directionToDb(GlDirection d) => switch (d) {
        GlDirection.moneyIn => 'money_in',
        GlDirection.moneyOut => 'money_out',
      };

  static GlDirection _directionFromDb(String value) => switch (value) {
        'money_in' => GlDirection.moneyIn,
        'money_out' => GlDirection.moneyOut,
        _ => throw ArgumentError('Unknown gl_direction: $value'),
      };
}
