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

import '../../domain/exceptions/app_role_exception.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../../domain/services/i_graph_app_role_service.dart';

/// Grants, changes, or revokes a Shedbooks app role for a user who has
/// already accessed the application (Users screen's role editor).
///
/// Unlike [SetMemberAppRoleUseCase][1], this targets an Entra object id
/// ([UserPresence.userId]) directly — no member lookup or O365 mailbox is
/// required, since the target has, by definition, already signed in.
///
/// Deliberately does not write to `user_presence` — that table's `role`
/// column is refreshed from the caller's own JWT on every authenticated
/// request (see presence_middleware.dart), so it self-corrects once the
/// affected user's browser acquires a fresh token; it must NOT be
/// overwritten here with the newly requested role, or it would show the
/// change as already in effect before Entra has actually issued a token
/// reflecting it.
///
/// [1]: ../o365/set_member_app_role_use_case.dart
class SetUserAppRoleUseCase {
  final IO365SyncSettingsRepository _settingsRepository;
  final IGraphAppRoleService _graphService;
  final String _resourceServicePrincipalId;

  const SetUserAppRoleUseCase(
    this._settingsRepository,
    this._graphService,
    this._resourceServicePrincipalId,
  );

  /// Throws:
  /// - [SelfRoleChangeException] if [targetUserId] equals [callerUserId].
  /// - [O365SyncNotConfiguredException] if no O365 settings have been saved.
  /// - [GraphAppRoleException] if the Graph session itself fails, or
  ///   [targetUserId] cannot be resolved to a user in the tenant.
  ///
  /// Returns the role now actually in effect (see
  /// [IGraphAppRoleService.setAppRole]).
  Future<String?> execute({
    required String entityId,
    required String callerUserId,
    required String targetUserId,
    required String? appRole,
  }) async {
    if (callerUserId.isNotEmpty && callerUserId == targetUserId) {
      throw const SelfRoleChangeException();
    }

    final settings = await _settingsRepository.find(entityId);
    if (settings == null) throw O365SyncNotConfiguredException();

    return _graphService.setAppRole(
      settings: settings,
      resourceServicePrincipalId: _resourceServicePrincipalId,
      targetUserId: targetUserId,
      appRole: appRole,
    );
  }
}
