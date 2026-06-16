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

import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/i_audit_repository.dart';

/// PostgreSQL implementation of [IAuditRepository].
class PostgresAuditRepository implements IAuditRepository {
  final Pool _pool;

  const PostgresAuditRepository(this._pool);

  @override
  Future<void> insert(AuditEntry entry) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO audit_log
          (entity_id, user_id, user_email, ip_address, method, path,
           action, table_name, record_id, status_code, changes)
        VALUES
          (@entityId, @userId, @userEmail, @ipAddress, @method, @path,
           @action, @tableName, @recordId, @statusCode, @changes::jsonb)
      '''),
      parameters: {
        'entityId': entry.entityId,
        'userId': entry.userId,
        'userEmail': entry.userEmail,
        'ipAddress': entry.ipAddress,
        'method': entry.method,
        'path': entry.path,
        'action': entry.action,
        'tableName': entry.tableName,
        'recordId': entry.recordId,
        'statusCode': entry.statusCode,
        'changes': entry.changes != null ? jsonEncode(entry.changes) : null,
      },
    );
  }

  @override
  Future<List<AuditEntry>> findAll({
    required String entityId,
    String? search,
    required int limit,
    required int offset,
  }) async {
    final pattern = search != null ? '%$search%' : null;
    final result = await _pool.execute(
      Sql.named('''
        SELECT id::text, entity_id, user_id, user_email, ip_address,
               method, path, action, table_name, record_id,
               status_code, changes, created_at
        FROM audit_log
        WHERE entity_id = @entityId
          AND (@pattern::text IS NULL OR (
            user_email  ILIKE @pattern OR
            ip_address  ILIKE @pattern OR
            action      ILIKE @pattern OR
            table_name  ILIKE @pattern OR
            COALESCE(record_id, '') ILIKE @pattern OR
            path        ILIKE @pattern OR
            method      ILIKE @pattern OR
            user_id     ILIKE @pattern
          ))
        ORDER BY created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {
        'entityId': entityId,
        'pattern': pattern,
        'limit': limit,
        'offset': offset,
      },
    );
    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<int> count({required String entityId, String? search}) async {
    final pattern = search != null ? '%$search%' : null;
    final result = await _pool.execute(
      Sql.named('''
        SELECT COUNT(*) AS total
        FROM audit_log
        WHERE entity_id = @entityId
          AND (@pattern::text IS NULL OR (
            user_email  ILIKE @pattern OR
            ip_address  ILIKE @pattern OR
            action      ILIKE @pattern OR
            table_name  ILIKE @pattern OR
            COALESCE(record_id, '') ILIKE @pattern OR
            path        ILIKE @pattern OR
            method      ILIKE @pattern OR
            user_id     ILIKE @pattern
          ))
      '''),
      parameters: {
        'entityId': entityId,
        'pattern': pattern,
      },
    );
    return result.first.toColumnMap()['total'] as int;
  }

  static AuditEntry _mapRow(Map<String, dynamic> row) {
    final rawChanges = row['changes'];
    Map<String, dynamic>? changes;
    if (rawChanges != null) {
      changes = rawChanges is Map
          ? Map<String, dynamic>.from(rawChanges)
          : jsonDecode(rawChanges.toString()) as Map<String, dynamic>;
    }

    return AuditEntry(
      id: row['id'] as String,
      entityId: row['entity_id'] as String,
      userId: row['user_id'] as String,
      userEmail: row['user_email'] as String,
      ipAddress: row['ip_address'] as String,
      method: row['method'] as String,
      path: row['path'] as String,
      action: row['action'] as String,
      tableName: row['table_name'] as String,
      recordId: row['record_id'] as String?,
      statusCode: row['status_code'] as int,
      changes: changes,
      createdAt: row['created_at'] as DateTime,
    );
  }
}
