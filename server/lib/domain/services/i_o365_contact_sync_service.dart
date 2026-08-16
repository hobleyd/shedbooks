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

import '../entities/member.dart';
import '../entities/o365_sync_settings.dart';
import '../exceptions/o365_sync_exception.dart';

/// Result of syncing one member within a batch.
class O365ContactSyncResult {
  final String memberId;

  /// The GAL mail contact's Exchange `.Identity`, set on success.
  final String? contactId;

  /// Set on a per-member failure (e.g. the member has no email address, or
  /// Exchange rejected the create/update). Null on success.
  final O365ContactSyncException? error;

  const O365ContactSyncResult({required this.memberId, this.contactId, this.error});

  /// True only when there's both no error AND a contact id to persist —
  /// guards callers that force-unwrap [contactId] on success (e.g.
  /// `markO365Synced`) against a malformed `{contactId: null, error: null}`
  /// result ever reaching them.
  bool get succeeded => error == null && contactId != null;
}

/// Pushes members into the tenant's Global Address List as organization-wide
/// mail contacts.
abstract interface class IO365ContactSyncService {
  /// Creates or updates the GAL mail contact for each of [members] in one
  /// authenticated session — connecting to Exchange Online is expensive
  /// (several seconds), so callers should always pass a whole batch rather
  /// than calling this once per member.
  ///
  /// Returns one [O365ContactSyncResult] per member, in the same order as
  /// [members]. A member with no email address is reported as a failed
  /// result (a mail contact cannot exist without one) rather than skipped
  /// silently.
  ///
  /// Throws [O365ContactSyncException] if the session itself could not be
  /// established (bad certificate, PowerShell/module unavailable, network
  /// failure) — in that case no member in the batch was attempted.
  Future<List<O365ContactSyncResult>> upsertContacts({
    required O365SyncSettings settings,
    required List<Member> members,
  });
}
