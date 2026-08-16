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

/// Per-entity Microsoft 365 settings used to push club members into the
/// tenant's Global Address List as organization-wide mail contacts.
///
/// Microsoft Graph has no supported write path for org-wide contacts in a
/// cloud-only tenant, so this authenticates to Exchange Online PowerShell
/// via certificate-based app-only auth against [tenantId]/[clientId], using
/// [certificatePfxBase64]/[certificatePassword] — not a client secret.
class O365SyncSettings {
  /// Organisation identifier from Auth0.
  final String entityId;

  /// Tenant's default domain (`<tenant>.onmicrosoft.com`, or a verified
  /// custom domain); passed as `Connect-ExchangeOnline -Organization`.
  /// Must NOT be the Tenant ID/Directory ID GUID — Microsoft's
  /// certificate-based auth requires the domain there and rejects a GUID
  /// (confirmed against a real tenant; see the "Tenant Domain" field's
  /// validation in `SaveO365SyncSettingsUseCase`).
  final String tenantId;

  /// Azure AD application (client) ID (GUID); passed as
  /// `Connect-ExchangeOnline -AppId`.
  final String clientId;

  /// Base64-encoded PKCS#12 (.pfx) certificate — public and private key.
  /// Decrypted server-side only; never serialized back to a client.
  final String certificatePfxBase64;

  /// Password protecting [certificatePfxBase64]. Decrypted server-side
  /// only; never serialized back to a client.
  final String certificatePassword;

  /// Expiry of [certificatePfxBase64]. Only known (non-null) when Shedbooks
  /// generated the certificate itself, rather than the admin uploading one.
  /// Not sensitive; safe to return to clients.
  final DateTime? certificateExpiresAt;

  /// Set the first time the manual "sync to O365" run is triggered.
  /// Auto-sync-on-write (from [Member] create/update) is disabled until
  /// this is non-null.
  final DateTime? initialSyncCompletedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const O365SyncSettings({
    required this.entityId,
    required this.tenantId,
    required this.clientId,
    required this.certificatePfxBase64,
    required this.certificatePassword,
    this.certificateExpiresAt,
    this.initialSyncCompletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True once the manual sync has been run at least once for this entity.
  bool get autoSyncEnabled => initialSyncCompletedAt != null;
}
