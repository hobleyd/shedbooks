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
           action, table_name, record_id, status_code)
        VALUES
          (@entityId, @userId, @userEmail, @ipAddress, @method, @path,
           @action, @tableName, @recordId, @statusCode)
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
               status_code, created_at
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
      createdAt: row['created_at'] as DateTime,
    );
  }
}
