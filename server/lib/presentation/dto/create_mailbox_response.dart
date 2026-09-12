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

import 'dart:convert';

import '../../application/o365/create_member_mailbox_use_case.dart';

/// Response DTO for `POST /members/<id>/create-mailbox`.
///
/// [temporaryPassword] is returned exactly once — it is never persisted
/// server-side, so this response is the admin's only chance to see and
/// relay it to the member.
class CreateMailboxResponse {
  final String upn;
  final String temporaryPassword;
  final bool licenseAssigned;
  final String? licenseWarning;

  const CreateMailboxResponse({
    required this.upn,
    required this.temporaryPassword,
    required this.licenseAssigned,
    this.licenseWarning,
  });

  factory CreateMailboxResponse.fromResult(CreateMailboxResult r) =>
      CreateMailboxResponse(
        upn: r.upn,
        temporaryPassword: r.temporaryPassword,
        licenseAssigned: r.licenseAssigned,
        licenseWarning: r.licenseWarning,
      );

  Map<String, dynamic> toJson() => {
        'upn': upn,
        'temporaryPassword': temporaryPassword,
        'licenseAssigned': licenseAssigned,
        'licenseWarning': licenseWarning,
      };

  String toJsonString() => jsonEncode(toJson());
}
