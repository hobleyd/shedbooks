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

/// Thrown when O365 sync settings input fails validation.
class O365SyncValidationException implements Exception {
  final String message;
  const O365SyncValidationException(this.message);

  @override
  String toString() => 'O365SyncValidationException: $message';
}

/// Thrown when a sync is attempted but no O365 settings have been saved
/// for the entity.
class O365SyncNotConfiguredException implements Exception {
  final String message = 'O365 sync has not been configured for this entity';

  @override
  String toString() => 'O365SyncNotConfiguredException: $message';
}

/// Represents a contact sync failure. Used two ways:
/// - as the `error` value on an individual `O365ContactSyncResult` when the
///   Exchange Online session connected fine but one member's
///   create/update failed (rejected payload, missing email, etc) — callers
///   should treat this as retryable and pending, not abort the batch;
/// - thrown directly by `IO365ContactSyncService.upsertContacts` when the
///   whole session fails before any per-member result exists (couldn't
///   connect, certificate rejected, PowerShell/module missing) — callers
///   should treat this as a systemic failure and abort the batch.
class O365ContactSyncException implements Exception {
  final String message;
  const O365ContactSyncException(this.message);

  @override
  String toString() => 'O365ContactSyncException: $message';
}

/// Thrown when generating a self-signed certificate fails (openssl
/// unavailable, timed out, or exited non-zero).
class O365CertificateGenerationException implements Exception {
  final String message;
  const O365CertificateGenerationException(this.message);

  @override
  String toString() => 'O365CertificateGenerationException: $message';
}
