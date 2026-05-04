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
    required String label,
    required String description,
    required bool gstApplicable,
  }) async {
    final id = _uuid.v4();

    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO general_ledger (id, label, description, gst_applicable)
        VALUES (@id::uuid, @label, @description, @gstApplicable)
        RETURNING id, label, description, gst_applicable, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'label': label,
        'description': description,
        'gstApplicable': gstApplicable,
      },
    );

    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<GeneralLedger?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, label, description, gst_applicable, created_at, updated_at, deleted_at
        FROM general_ledger
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<GeneralLedger>> findAll() async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, label, description, gst_applicable, created_at, updated_at, deleted_at
        FROM general_ledger
        WHERE deleted_at IS NULL
        ORDER BY label ASC
      '''),
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<GeneralLedger> update({
    required String id,
    required String label,
    required String description,
    required bool gstApplicable,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE general_ledger
        SET label          = @label,
            description    = @description,
            gst_applicable = @gstApplicable,
            updated_at     = NOW()
        WHERE id = @id::uuid
          AND deleted_at IS NULL
        RETURNING id, label, description, gst_applicable, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'label': label,
        'description': description,
        'gstApplicable': gstApplicable,
      },
    );

    if (result.isEmpty) throw GeneralLedgerNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE general_ledger
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id},
    );

    if (result.affectedRows == 0) throw GeneralLedgerNotFoundException(id);
  }

  GeneralLedger _mapRow(Map<String, dynamic> row) {
    return GeneralLedger(
      id: row['id'].toString(),
      label: row['label'] as String,
      description: row['description'] as String,
      gstApplicable: row['gst_applicable'] as bool,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }
}
