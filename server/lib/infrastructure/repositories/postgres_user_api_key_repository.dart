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

import '../../domain/entities/user_api_key.dart';
import '../../domain/repositories/i_user_api_key_repository.dart';

/// PostgreSQL implementation of [IUserApiKeyRepository].
class PostgresUserApiKeyRepository implements IUserApiKeyRepository {
  final Pool _pool;

  const PostgresUserApiKeyRepository(this._pool);

  @override
  Future<UserApiKey?> findByApiKeyHash(String hash) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, entity_id, user_id, user_email, api_key_hash, created_at
        FROM user_api_keys
        WHERE api_key_hash = @hash
      '''),
      parameters: {'hash': hash},
    );
    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<UserApiKey?> findByUser({
    required String entityId,
    required String userId,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT id, entity_id, user_id, user_email, api_key_hash, created_at
        FROM user_api_keys
        WHERE entity_id = @entityId AND user_id = @userId
      '''),
      parameters: {'entityId': entityId, 'userId': userId},
    );
    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> upsert(UserApiKey key) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO user_api_keys
          (id, entity_id, user_id, user_email, api_key_hash, created_at)
        VALUES
          (@id::uuid, @entityId, @userId, @userEmail, @apiKeyHash, @createdAt)
        ON CONFLICT (entity_id, user_id) DO UPDATE
          SET user_email   = EXCLUDED.user_email,
              api_key_hash = EXCLUDED.api_key_hash,
              created_at   = EXCLUDED.created_at
      '''),
      parameters: {
        'id': key.id,
        'entityId': key.entityId,
        'userId': key.userId,
        'userEmail': key.userEmail,
        'apiKeyHash': key.apiKeyHash,
        'createdAt': key.createdAt,
      },
    );
  }

  static UserApiKey _mapRow(Map<String, dynamic> row) => UserApiKey(
        id: row['id'].toString(),
        entityId: row['entity_id'] as String,
        userId: row['user_id'] as String,
        userEmail: row['user_email'] as String,
        apiKeyHash: row['api_key_hash'] as String,
        createdAt: row['created_at'] as DateTime,
      );
}
