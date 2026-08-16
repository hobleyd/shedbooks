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

import 'package:logging/logging.dart';

import '../../domain/entities/member.dart';
import '../../domain/repositories/i_member_repository.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../../domain/services/i_o365_contact_sync_service.dart';

/// Pushes a single member to O365 immediately after it is created or
/// updated, once the entity has completed its first manual sync run.
///
/// Invoked with `unawaited()` from `CreateMemberUseCase`/`UpdateMemberUseCase`
/// — a Connect-ExchangeOnline session can take 10-20 seconds, and that must
/// never block the member-save HTTP response. Never throws: failures are
/// logged and the member is simply left pending, picked up by the next
/// manual "sync to O365" run (which is itself the retry mechanism — no
/// separate retry queue).
class MemberO365AutoSync {
  static final _log = Logger('MemberO365AutoSync');

  final IO365SyncSettingsRepository _settingsRepository;
  final IMemberRepository _memberRepository;
  final IO365ContactSyncService _syncService;

  const MemberO365AutoSync(
    this._settingsRepository,
    this._memberRepository,
    this._syncService,
  );

  /// No-ops when O365 sync isn't configured, or hasn't completed its first
  /// manual run for [entityId] yet.
  Future<void> maybeSync(String entityId, Member member) async {
    try {
      final settings = await _settingsRepository.find(entityId);
      if (settings == null || !settings.autoSyncEnabled) return;

      final results = await _syncService.upsertContacts(
        settings: settings,
        members: [member],
      );
      final result = results.single;
      if (!result.succeeded) {
        _log.warning(
            'O365 auto-sync failed for member ${member.id}: ${result.error}');
        return;
      }

      await _memberRepository.markO365Synced(
        id: member.id,
        entityId: entityId,
        o365ContactId: result.contactId!,
      );
    } catch (e, st) {
      _log.warning('O365 auto-sync failed for member ${member.id}', e, st);
    }
  }
}
