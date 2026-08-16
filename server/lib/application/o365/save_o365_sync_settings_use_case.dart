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

import '../../domain/entities/o365_sync_settings.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';

/// Creates or updates the O365 sync settings for an entity.
class SaveO365SyncSettingsUseCase {
  final IO365SyncSettingsRepository _repository;

  const SaveO365SyncSettingsUseCase(this._repository);

  /// Matches a bare GUID (with or without hyphens is not needed here — the
  /// Tenant ID/Directory ID Azure surfaces is always hyphenated).
  static final RegExp _guidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Validates input and upserts settings.
  ///
  /// [certificatePfxBase64] and [certificatePassword] are write-only
  /// fields: pass a blank/null value to keep the previously saved value
  /// unchanged (used when the client re-submits the form without
  /// re-uploading a certificate — neither is ever echoed back by the GET
  /// endpoint, so this is the only way to leave them as-is). They are
  /// independent — e.g. re-entering just the password without re-uploading
  /// the certificate is valid.
  ///
  /// [certificateExpiresAt] is only meaningful alongside a non-blank
  /// [certificatePfxBase64] (a new certificate). It is saved as given for
  /// generated certificates, or left null for a manually uploaded one (its
  /// expiry is never inspected). When [certificatePfxBase64] is blank the
  /// previously saved expiry is preserved regardless of this parameter.
  ///
  /// [initialSyncCompletedAt] is never set here — it is preserved from any
  /// existing row and only ever flipped on by
  /// `IO365SyncSettingsRepository.markInitialSyncCompleted`, which is called
  /// by `SyncMembersToO365UseCase`.
  ///
  /// Throws [O365SyncValidationException] when [tenantId] or [clientId] are
  /// blank, [tenantId] looks like a bare GUID (the certificate-based
  /// connection requires the tenant's domain, not the Tenant ID/Directory
  /// ID GUID — a very easy mix-up since Entra ID's Overview page surfaces
  /// both), or no certificate/password is available (neither a new one nor
  /// a previously saved one).
  Future<O365SyncSettings> execute({
    required String entityId,
    required String tenantId,
    required String clientId,
    String? certificatePfxBase64,
    String? certificatePassword,
    DateTime? certificateExpiresAt,
  }) async {
    final trimmedTenantId = tenantId.trim();
    final trimmedClientId = clientId.trim();

    if (trimmedTenantId.isEmpty) {
      throw const O365SyncValidationException('Tenant Domain must not be empty');
    }
    if (_guidPattern.hasMatch(trimmedTenantId)) {
      throw const O365SyncValidationException(
          'Tenant Domain must be your tenant\'s domain (e.g. '
          'yourclub.onmicrosoft.com), not the Tenant ID GUID — Exchange '
          'Online\'s certificate-based connection requires the domain and '
          'will reject a GUID.');
    }
    if (trimmedClientId.isEmpty) {
      throw const O365SyncValidationException('Client ID must not be empty');
    }

    final existing = await _repository.find(entityId);

    final trimmedPfx = certificatePfxBase64?.trim();
    final isNewCert = trimmedPfx != null && trimmedPfx.isNotEmpty;
    final effectivePfx = isNewCert ? trimmedPfx : existing?.certificatePfxBase64;
    if (effectivePfx == null || effectivePfx.isEmpty) {
      throw const O365SyncValidationException('Certificate must not be empty');
    }
    final effectiveExpiresAt =
        isNewCert ? certificateExpiresAt : existing?.certificateExpiresAt;

    final trimmedPassword = certificatePassword?.trim();
    final effectivePassword = (trimmedPassword != null && trimmedPassword.isNotEmpty)
        ? trimmedPassword
        : existing?.certificatePassword;
    if (effectivePassword == null || effectivePassword.isEmpty) {
      throw const O365SyncValidationException(
          'Certificate password must not be empty');
    }

    final now = DateTime.now().toUtc();
    return _repository.save(O365SyncSettings(
      entityId: entityId,
      tenantId: trimmedTenantId,
      clientId: trimmedClientId,
      certificatePfxBase64: effectivePfx,
      certificatePassword: effectivePassword,
      certificateExpiresAt: effectiveExpiresAt,
      initialSyncCompletedAt: existing?.initialSyncCompletedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    ));
  }
}
