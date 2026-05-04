import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// PostgreSQL implementation of [IContactRepository].
class PostgresContactRepository implements IContactRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresContactRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  @override
  Future<Contact> create({
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
  }) async {
    final id = _uuid.v4();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO contacts (id, name, contact_type, gst_registered)
        VALUES (@id::uuid, @name, @contactType::contact_type, @gstRegistered)
        RETURNING id, name, contact_type, gst_registered, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'name': name,
        'contactType': contactType.name,
        'gstRegistered': gstRegistered,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<Contact?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, name, contact_type, gst_registered, created_at, updated_at, deleted_at
        FROM contacts
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<Contact>> findAll() async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, name, contact_type, gst_registered, created_at, updated_at, deleted_at
        FROM contacts
        WHERE deleted_at IS NULL
        ORDER BY name ASC
      '''),
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<Contact> update({
    required String id,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE contacts
        SET name           = @name,
            contact_type   = @contactType::contact_type,
            gst_registered = @gstRegistered,
            updated_at     = NOW()
        WHERE id = @id::uuid
          AND deleted_at IS NULL
        RETURNING id, name, contact_type, gst_registered, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'name': name,
        'contactType': contactType.name,
        'gstRegistered': gstRegistered,
      },
    );

    if (result.isEmpty) throw ContactNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE contacts
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id},
    );

    if (result.affectedRows == 0) throw ContactNotFoundException(id);
  }

  Contact _mapRow(Map<String, dynamic> row) {
    return Contact(
      id: row['id'].toString(),
      name: row['name'] as String,
      contactType: ContactType.values.byName(row['contact_type'] as String),
      gstRegistered: row['gst_registered'] as bool,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }
}
