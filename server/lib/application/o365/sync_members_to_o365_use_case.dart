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

import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/repositories/i_member_repository.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../../domain/services/i_o365_contact_sync_service.dart';

/// Outcome of one [SyncMembersToO365UseCase] run.
class O365SyncBatchResult {
  /// Members successfully pushed to O365 this run.
  final int synced;

  /// Members that failed this run and remain pending for the next run.
  final int failed;

  /// Members still pending after this run (includes [failed] plus any
  /// beyond the batch limit that were not attempted).
  final int remaining;

  const O365SyncBatchResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });
}

/// Pushes members that have never been synced (or were edited since their
/// last sync) into O365 as Global Address List mail contacts.
///
/// Processes at most [batchLimit] members per call, in one Exchange Online
/// PowerShell session, so a single HTTP request can't run indefinitely
/// behind the reverse proxy; the caller re-invokes this use case while
/// `remaining > 0` to fully drain a large backlog. Per-member failures are
/// swallowed (fail-soft) so one bad record doesn't abort the whole batch —
/// the member simply stays pending for the next run. If the Exchange Online
/// session itself can't be established, the whole batch fails and the
/// exception propagates (there's nothing to salvage — no member was
/// attempted).
///
/// [_defaultBatchLimit] is sized against Exchange Online session overhead
/// (module import + `Connect-ExchangeOnline`, several seconds) plus a few
/// cmdlets per member, against nginx's `proxy_read_timeout` — see
/// `client/nginx.conf`, which this feature raises above the 60s default to
/// give this call headroom.
class SyncMembersToO365UseCase {
  static const _defaultBatchLimit = 5;

  final IO365SyncSettingsRepository _settingsRepository;
  final IMemberRepository _memberRepository;
  final IO365ContactSyncService _syncService;

  const SyncMembersToO365UseCase(
    this._settingsRepository,
    this._memberRepository,
    this._syncService,
  );

  /// Throws [O365SyncNotConfiguredException] if no settings have been saved
  /// for [entityId], or [O365ContactSyncException] if the Exchange Online
  /// session could not be established.
  Future<O365SyncBatchResult> execute({
    required String entityId,
    int batchLimit = _defaultBatchLimit,
  }) async {
    final settings = await _settingsRepository.find(entityId);
    if (settings == null) throw O365SyncNotConfiguredException();

    // Triggering a sync run at all satisfies "synced at least once" — flip
    // auto-sync-on-write on now, even if this run doesn't fully drain the
    // backlog, so newly edited members stop accumulating further behind.
    await _settingsRepository.markInitialSyncCompleted(entityId);

    final pending = await _memberRepository.findPendingO365Sync(
      entityId: entityId,
      limit: batchLimit,
    );

    var synced = 0;
    var failed = 0;

    if (pending.isNotEmpty) {
      final results = await _syncService.upsertContacts(
        settings: settings,
        members: pending,
      );

      for (final result in results) {
        if (result.succeeded) {
          await _memberRepository.markO365Synced(
            id: result.memberId,
            entityId: entityId,
            o365ContactId: result.contactId!,
          );
          synced++;
        } else {
          failed++;
        }
      }
    }

    final remaining =
        await _memberRepository.countPendingO365Sync(entityId: entityId);

    return O365SyncBatchResult(
      synced: synced,
      failed: failed,
      remaining: remaining,
    );
  }
}
