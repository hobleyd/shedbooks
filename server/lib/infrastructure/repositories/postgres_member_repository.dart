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

import '../../domain/entities/member.dart';
import '../../domain/exceptions/member_exception.dart';
import '../../domain/repositories/i_member_repository.dart';
import '../encryption/field_encryptor.dart';

/// PostgreSQL implementation of [IMemberRepository].
///
/// The fields [streetAddress], [email], [phone], [dateOfBirth], and
/// [emergencyContact] are stored encrypted with AES-256-GCM via
/// [FieldEncryptor]. Legacy plaintext rows (written before encryption was
/// introduced) are returned as-is and re-encrypted on the next write.
class PostgresMemberRepository implements IMemberRepository {
  final Pool _pool;
  final Uuid _uuid;
  final FieldEncryptor _enc;

  PostgresMemberRepository(this._pool, FieldEncryptor encryptor, [Uuid? uuid])
      : _enc = encryptor,
        _uuid = uuid ?? const Uuid();

  static const _columns = '''
    id, entity_id, first_name, last_name, date_joined, membership_status,
    street_address, po_box, email, phone, date_of_birth,
    emergency_contact, woodworking_induction, metalworking_induction, gym_waiver,
    etag, created_at, updated_at, deleted_at
  ''';

  @override
  Future<Member> create({
    required String entityId,
    required String firstName,
    required String lastName,
    DateTime? dateJoined,
    String? membershipStatus,
    String? streetAddress,
    String? poBox,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? emergencyContact,
    DateTime? woodworkingInduction,
    DateTime? metalworkingInduction,
    DateTime? gymWaiver,
  }) async {
    final id = _uuid.v4();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO members (
          id, entity_id, first_name, last_name, date_joined, membership_status,
          street_address, po_box, email, phone, date_of_birth,
          emergency_contact, woodworking_induction, metalworking_induction, gym_waiver
        ) VALUES (
          @id::uuid, @entityId, @firstName, @lastName, @dateJoined, @membershipStatus,
          @streetAddress, @poBox, @email, @phone, @dateOfBirth,
          @emergencyContact, @woodworkingInduction, @metalworkingInduction, @gymWaiver
        )
        RETURNING $_columns
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'firstName': firstName,
        'lastName': lastName,
        'dateJoined': dateJoined,
        'membershipStatus': membershipStatus,
        'streetAddress': _encStr(streetAddress),
        'poBox': poBox,
        'email': _encStr(email),
        'phone': _encStr(phone),
        'dateOfBirth': _encDate(dateOfBirth),
        'emergencyContact': _encStr(emergencyContact),
        'woodworkingInduction': woodworkingInduction,
        'metalworkingInduction': metalworkingInduction,
        'gymWaiver': gymWaiver,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<Member?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_columns
        FROM members
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
  Future<List<Member>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_columns
        FROM members
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY last_name ASC, first_name ASC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<Member> update({
    required String id,
    required String entityId,
    required String firstName,
    required String lastName,
    DateTime? dateJoined,
    String? membershipStatus,
    String? streetAddress,
    String? poBox,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? emergencyContact,
    DateTime? woodworkingInduction,
    DateTime? metalworkingInduction,
    DateTime? gymWaiver,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE members
        SET first_name              = @firstName,
            last_name               = @lastName,
            date_joined             = @dateJoined,
            membership_status       = @membershipStatus,
            street_address          = @streetAddress,
            po_box                  = @poBox,
            email                   = @email,
            phone                   = @phone,
            date_of_birth           = @dateOfBirth,
            emergency_contact       = @emergencyContact,
            woodworking_induction   = @woodworkingInduction,
            metalworking_induction  = @metalworkingInduction,
            gym_waiver              = @gymWaiver,
            etag                    = uuid_generate_v4()::text,
            updated_at              = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
        RETURNING $_columns
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'firstName': firstName,
        'lastName': lastName,
        'dateJoined': dateJoined,
        'membershipStatus': membershipStatus,
        'streetAddress': _encStr(streetAddress),
        'poBox': poBox,
        'email': _encStr(email),
        'phone': _encStr(phone),
        'dateOfBirth': _encDate(dateOfBirth),
        'emergencyContact': _encStr(emergencyContact),
        'woodworkingInduction': woodworkingInduction,
        'metalworkingInduction': metalworkingInduction,
        'gymWaiver': gymWaiver,
      },
    );
    if (result.isEmpty) throw MemberNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE members
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.affectedRows == 0) throw MemberNotFoundException(id);
  }

  @override
  Future<List<Member>> importMany({
    required String entityId,
    required List<MemberImportData> members,
  }) async {
    final results = <Member>[];
    await _pool.runTx((tx) async {
      for (final m in members) {
        final id = _uuid.v4();
        final result = await tx.execute(
          Sql.named('''
            INSERT INTO members (
              id, entity_id, first_name, last_name, date_joined, membership_status,
              street_address, po_box, email, phone, date_of_birth,
              emergency_contact, woodworking_induction, metalworking_induction, gym_waiver
            ) VALUES (
              @id::uuid, @entityId, @firstName, @lastName, @dateJoined, @membershipStatus,
              @streetAddress, @poBox, @email, @phone, @dateOfBirth,
              @emergencyContact, @woodworkingInduction, @metalworkingInduction, @gymWaiver
            )
            RETURNING $_columns
          '''),
          parameters: {
            'id': id,
            'entityId': entityId,
            'firstName': m.firstName,
            'lastName': m.lastName,
            'dateJoined': m.dateJoined,
            'membershipStatus': m.membershipStatus,
            'streetAddress': _encStr(m.streetAddress),
            'poBox': m.poBox,
            'email': _encStr(m.email),
            'phone': _encStr(m.phone),
            'dateOfBirth': _encDate(m.dateOfBirth),
            'emergencyContact': _encStr(m.emergencyContact),
            'woodworkingInduction': m.woodworkingInduction,
            'metalworkingInduction': m.metalworkingInduction,
            'gymWaiver': m.gymWaiver,
          },
        );
        results.add(_mapRow(result.first.toColumnMap()));
      }
    });
    return results;
  }

  Member _mapRow(Map<String, dynamic> row) {
    DateTime? _date(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    return Member(
      id: row['id'].toString(),
      entityId: row['entity_id'] as String,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      dateJoined: _date(row['date_joined']),
      membershipStatus: row['membership_status'] as String?,
      streetAddress: _decStr(row['street_address']),
      poBox: row['po_box'] as String?,
      email: _decStr(row['email']),
      phone: _decStr(row['phone']),
      dateOfBirth: _decDate(row['date_of_birth']),
      emergencyContact: _decStr(row['emergency_contact']),
      woodworkingInduction: _date(row['woodworking_induction']),
      metalworkingInduction: _date(row['metalworking_induction']),
      gymWaiver: _date(row['gym_waiver']),
      etag: row['etag'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }

  String? _decStr(dynamic v) =>
      v != null ? _enc.decrypt(v as String) : null;

  /// Decrypts an encrypted ISO-8601 date string (e.g. "enc:<base64>") and
  /// returns a UTC [DateTime], or decodes a legacy plaintext "YYYY-MM-DD" value
  /// written before encryption was introduced.
  DateTime? _decDate(dynamic v) {
    if (v == null) return null;
    final s = _enc.decrypt(v as String);
    final parts = s.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  String? _encStr(String? s) => s != null ? _enc.encrypt(s) : null;

  /// Encrypts a [DateTime] as an ISO-8601 date string ("YYYY-MM-DD").
  String? _encDate(DateTime? d) {
    if (d == null) return null;
    final s =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return _enc.encrypt(s);
  }
}
