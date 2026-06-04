import 'package:postgres/postgres.dart';

import '../../domain/entities/user_presence.dart';
import '../../domain/repositories/i_user_presence_repository.dart';

/// PostgreSQL implementation of [IUserPresenceRepository].
class PostgresUserPresenceRepository implements IUserPresenceRepository {
  final Pool _pool;

  const PostgresUserPresenceRepository(this._pool);

  @override
  Future<void> upsert(UserPresence presence) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO user_presence
          (entity_id, user_id, user_email, role, last_seen, ip_address)
        VALUES
          (@entityId, @userId, @userEmail, @role, NOW(), @ipAddress)
        ON CONFLICT (entity_id, user_id) DO UPDATE
          SET user_email = EXCLUDED.user_email,
              role       = EXCLUDED.role,
              last_seen  = NOW(),
              ip_address = EXCLUDED.ip_address
      '''),
      parameters: {
        'entityId': presence.entityId,
        'userId': presence.userId,
        'userEmail': presence.userEmail,
        'role': presence.role,
        'ipAddress': presence.ipAddress,
      },
    );
  }

  @override
  Future<List<UserPresence>> findAllByEntity(String entityId) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT entity_id, user_id, user_email, role, last_seen, ip_address
        FROM user_presence
        WHERE entity_id = @entityId
        ORDER BY last_seen DESC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  static UserPresence _mapRow(Map<String, dynamic> row) => UserPresence(
        entityId: row['entity_id'] as String,
        userId: row['user_id'] as String,
        userEmail: row['user_email'] as String,
        role: row['role'] as String,
        lastSeen: row['last_seen'] as DateTime,
        ipAddress: row['ip_address'] as String,
      );
}
