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

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';
import '../encryption/field_encryptor.dart';

/// PostgreSQL implementation of [IContactRepository].
class PostgresContactRepository implements IContactRepository {
  final Pool _pool;
  final Uuid _uuid;
  final FieldEncryptor _enc;

  PostgresContactRepository(this._pool, FieldEncryptor encryptor, [Uuid? uuid])
      : _enc = encryptor,
        _uuid = uuid ?? const Uuid();

  @override
  Future<Contact> create({
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
  }) async {
    final id = _uuid.v4();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO contacts (id, entity_id, name, contact_type, gst_registered, abn, bsb, account_number)
        VALUES (@id::uuid, @entityId, @name, @contactType::contact_type, @gstRegistered, @abn, @bsb, @accountNumber)
        RETURNING id, name, contact_type::text, gst_registered, abn, bsb, account_number, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'name': name,
        'contactType': contactType.name,
        'gstRegistered': gstRegistered,
        'abn': abn,
        'bsb': bsb != null ? _enc.encrypt(bsb) : null,
        'accountNumber': accountNumber != null ? _enc.encrypt(accountNumber) : null,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<Contact?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, name, contact_type::text, gst_registered, abn, bsb, account_number, created_at, updated_at, deleted_at
        FROM contacts
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
  Future<List<Contact>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, name, contact_type::text, gst_registered, abn, bsb, account_number, created_at, updated_at, deleted_at
        FROM contacts
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY name ASC
      '''),
      parameters: {'entityId': entityId},
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<Contact> update({
    required String id,
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE contacts
        SET name           = @name,
            contact_type   = @contactType::contact_type,
            gst_registered = @gstRegistered,
            abn            = @abn,
            bsb            = @bsb,
            account_number = @accountNumber,
            updated_at     = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
        RETURNING id, name, contact_type::text, gst_registered, abn, bsb, account_number, created_at, updated_at, deleted_at
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'name': name,
        'contactType': contactType.name,
        'gstRegistered': gstRegistered,
        'abn': abn,
        'bsb': bsb != null ? _enc.encrypt(bsb) : null,
        'accountNumber': accountNumber != null ? _enc.encrypt(accountNumber) : null,
      },
    );

    if (result.isEmpty) throw ContactNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE contacts
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.affectedRows == 0) throw ContactNotFoundException(id);
  }

  Contact _mapRow(Map<String, dynamic> row) {
    return Contact(
      id: row['id'].toString(),
      name: row['name'] as String,
      contactType: ContactType.values.byName(row['contact_type'] as String),
      gstRegistered: row['gst_registered'] as bool,
      abn: (row['abn'] as String?)?.trim(),
      bsb: row['bsb'] != null ? _enc.decrypt(row['bsb'] as String) : null,
      accountNumber: row['account_number'] != null
          ? _enc.decrypt(row['account_number'] as String)
          : null,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }
}
