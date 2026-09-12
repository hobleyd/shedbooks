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

import '../../domain/exceptions/member_exception.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/repositories/i_member_repository.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';
import '../../domain/services/i_o365_mailbox_service.dart';
import '../../domain/services/o365_local_part.dart';
import '../../infrastructure/security/temporary_password_generator.dart';

/// Outcome of [CreateMemberMailboxUseCase.execute].
class CreateMailboxResult {
  /// The tenant sign-in address created for the member.
  final String upn;

  /// The one-time temporary password — never persisted anywhere; the
  /// caller (an admin, via the API response) is the only place this value
  /// exists once this method returns.
  final String temporaryPassword;

  /// False if the mailbox was created but license assignment failed — the
  /// account and password are still valid, but no mail can flow until an
  /// admin assigns a license manually.
  final bool licenseAssigned;

  final String? licenseWarning;

  const CreateMailboxResult({
    required this.upn,
    required this.temporaryPassword,
    required this.licenseAssigned,
    this.licenseWarning,
  });
}

/// Creates a tenant sign-in account (Entra ID user + Exchange mailbox) for
/// a club member, named `firstname.surname@<tenant domain>`, with a
/// generated temporary password the admin hands to the member.
class CreateMemberMailboxUseCase {
  final IO365SyncSettingsRepository _settingsRepository;
  final IMemberRepository _memberRepository;
  final IO365MailboxService _mailboxService;
  final TemporaryPasswordGenerator _passwordGenerator;

  const CreateMemberMailboxUseCase(
    this._settingsRepository,
    this._memberRepository,
    this._mailboxService,
    this._passwordGenerator,
  );

  /// Throws:
  /// - [O365SyncNotConfiguredException] if no O365 settings have been saved.
  /// - [MemberNotFoundException] if [memberId] doesn't exist for [entityId].
  /// - [O365MailboxConflictException] if the member already has a mailbox,
  ///   or the tenant already has an account at the address their name
  ///   normalizes to (e.g. another member shares that name) — no
  ///   automatic suffix is generated; an admin must resolve it.
  /// - [O365MailboxException] if the O365 session itself fails, or the
  ///   chosen license no longer has a spare seat.
  Future<CreateMailboxResult> execute({
    required String memberId,
    required String entityId,
    required String licenseSkuId,
  }) async {
    final settings = await _settingsRepository.find(entityId);
    if (settings == null) throw O365SyncNotConfiguredException();

    final member = await _memberRepository.findById(memberId, entityId: entityId);
    if (member == null) throw MemberNotFoundException(memberId);

    if (member.hasO365Mailbox) {
      throw O365MailboxConflictException(
          'Member already has an O365 mailbox: ${member.o365MailboxUpn}');
    }

    final localPart =
        buildO365LocalPart(firstName: member.firstName, lastName: member.lastName);
    final temporaryPassword = _passwordGenerator.generate();

    final result = await _mailboxService.createMailbox(
      settings: settings,
      firstName: member.firstName,
      lastName: member.lastName,
      localPart: localPart,
      temporaryPassword: temporaryPassword,
      licenseSkuId: licenseSkuId,
    );

    await _memberRepository.markO365MailboxCreated(
      id: memberId,
      entityId: entityId,
      upn: result.upn,
    );

    return CreateMailboxResult(
      upn: result.upn,
      temporaryPassword: temporaryPassword,
      licenseAssigned: result.licenseAssigned,
      licenseWarning: result.licenseAssigned
          ? null
          : 'Mailbox created, but the license could not be assigned automatically '
              '(${result.licenseError}). Assign one manually in the Microsoft 365 admin center.',
    );
  }
}
