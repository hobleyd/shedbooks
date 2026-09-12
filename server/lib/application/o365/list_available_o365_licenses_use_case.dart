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
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../../domain/services/i_o365_mailbox_service.dart';

/// Lists Microsoft 365 license SKUs with spare seats, so the admin can pick
/// one before creating a member's mailbox (see [CreateMemberMailboxUseCase]).
class ListAvailableO365LicensesUseCase {
  final IO365SyncSettingsRepository _settingsRepository;
  final IO365MailboxService _mailboxService;

  const ListAvailableO365LicensesUseCase(
    this._settingsRepository,
    this._mailboxService,
  );

  /// Throws [O365SyncNotConfiguredException] if no O365 settings have been
  /// saved for [entityId], or [O365MailboxException] if the Graph session
  /// could not be established.
  Future<List<O365LicenseOption>> execute({required String entityId}) async {
    final settings = await _settingsRepository.find(entityId);
    if (settings == null) throw O365SyncNotConfiguredException();
    return _mailboxService.listAvailableLicenses(settings: settings);
  }
}
