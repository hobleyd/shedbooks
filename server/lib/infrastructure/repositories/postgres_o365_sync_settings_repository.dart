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

import '../../domain/entities/o365_sync_settings.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../encryption/field_encryptor.dart';

/// PostgreSQL implementation of [IO365SyncSettingsRepository].
///
/// [O365SyncSettings.certificatePfxBase64] and
/// [O365SyncSettings.certificatePassword] are stored encrypted with
/// AES-256-GCM via [FieldEncryptor].
class PostgresO365SyncSettingsRepository
    implements IO365SyncSettingsRepository {
  final Pool _pool;
  final FieldEncryptor _enc;

  const PostgresO365SyncSettingsRepository(this._pool, this._enc);

  static const _columns = '''
    entity_id, tenant_id, client_id,
    certificate_pfx, certificate_password,
    certificate_expires_at, initial_sync_completed_at, created_at, updated_at
  ''';

  @override
  Future<O365SyncSettings?> find(String entityId) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM o365_sync_settings WHERE entity_id = @entityId'),
      parameters: {'entityId': entityId},
    );
    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<O365SyncSettings> save(O365SyncSettings settings) async {
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO o365_sync_settings
          (entity_id, tenant_id, client_id,
           certificate_pfx, certificate_password,
           certificate_expires_at, initial_sync_completed_at)
        VALUES
          (@entityId, @tenantId, @clientId,
           @certificatePfx, @certificatePassword,
           @certificateExpiresAt, @initialSyncCompletedAt)
        ON CONFLICT (entity_id) DO UPDATE
          SET tenant_id                    = EXCLUDED.tenant_id,
              client_id                    = EXCLUDED.client_id,
              certificate_pfx              = EXCLUDED.certificate_pfx,
              certificate_password         = EXCLUDED.certificate_password,
              certificate_expires_at       = EXCLUDED.certificate_expires_at,
              initial_sync_completed_at    = EXCLUDED.initial_sync_completed_at,
              updated_at                   = NOW()
        RETURNING $_columns
      '''),
      parameters: {
        'entityId': settings.entityId,
        'tenantId': settings.tenantId,
        'clientId': settings.clientId,
        'certificatePfx': _enc.encrypt(settings.certificatePfxBase64),
        'certificatePassword': _enc.encrypt(settings.certificatePassword),
        'certificateExpiresAt': settings.certificateExpiresAt,
        'initialSyncCompletedAt': settings.initialSyncCompletedAt,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> markInitialSyncCompleted(String entityId) async {
    await _pool.execute(
      Sql.named('''
        UPDATE o365_sync_settings
        SET initial_sync_completed_at = COALESCE(initial_sync_completed_at, NOW())
        WHERE entity_id = @entityId
      '''),
      parameters: {'entityId': entityId},
    );
  }

  O365SyncSettings _mapRow(Map<String, dynamic> row) => O365SyncSettings(
        entityId: row['entity_id'] as String,
        tenantId: row['tenant_id'] as String,
        clientId: row['client_id'] as String,
        certificatePfxBase64: _enc.decrypt(row['certificate_pfx'] as String),
        certificatePassword: _enc.decrypt(row['certificate_password'] as String),
        certificateExpiresAt: row['certificate_expires_at'] as DateTime?,
        initialSyncCompletedAt: row['initial_sync_completed_at'] as DateTime?,
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );
}
