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
import '../../domain/exceptions/member_exception.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/repositories/i_member_repository.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../../domain/services/i_graph_app_role_service.dart';

/// Grants, changes, or revokes a Shedbooks app role for a member's O365
/// mailbox account (Membership screen's access-management action).
///
/// A member must already have a tenant mailbox ([Member.hasO365Mailbox]) —
/// app role assignment requires a real Entra ID user object, which only
/// "Create O365 mailbox" creates.
class SetMemberAppRoleUseCase {
  final IMemberRepository _memberRepository;
  final IO365SyncSettingsRepository _settingsRepository;
  final IGraphAppRoleService _graphService;
  final String _resourceServicePrincipalId;

  const SetMemberAppRoleUseCase(
    this._memberRepository,
    this._settingsRepository,
    this._graphService,
    this._resourceServicePrincipalId,
  );

  /// Throws:
  /// - [MemberNotFoundException] if [memberId] doesn't exist for [entityId].
  /// - [MemberValidationException] if the member has no O365 mailbox yet.
  /// - [SelfRoleChangeException] if [callerEmail] matches the member's
  ///   mailbox address — an administrator changing their own access could
  ///   lock themselves out with no one able to undo it from within the app.
  /// - [O365SyncNotConfiguredException] if no O365 settings have been saved.
  /// - [GraphAppRoleException] if the Graph session itself fails.
  ///
  /// Returns the role now actually in effect (see
  /// [IGraphAppRoleService.setAppRole]), after persisting it as
  /// [Member.shedbooksAppRole].
  Future<String?> execute({
    required String memberId,
    required String entityId,
    required String? appRole,
    required String callerEmail,
  }) async {
    final member = await _memberRepository.findById(memberId, entityId: entityId);
    if (member == null) throw MemberNotFoundException(memberId);

    if (!member.hasO365Mailbox) {
      throw const MemberValidationException(
        'This member needs a tenant mailbox (use "Create O365 mailbox") '
        'before they can be granted Shedbooks access.',
      );
    }

    if (callerEmail.isNotEmpty &&
        callerEmail.toLowerCase() == member.o365MailboxUpn!.toLowerCase()) {
      throw const SelfRoleChangeException();
    }

    final settings = await _settingsRepository.find(entityId);
    if (settings == null) throw O365SyncNotConfiguredException();

    final resultingRole = await _graphService.setAppRole(
      settings: settings,
      resourceServicePrincipalId: _resourceServicePrincipalId,
      targetUserId: member.o365MailboxUpn!,
      appRole: appRole,
    );

    await _memberRepository.setShedbooksAppRole(
      id: memberId,
      entityId: entityId,
      role: resultingRole,
    );

    return resultingRole;
  }
}
