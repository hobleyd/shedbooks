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

/// Request DTO for `POST /admin/o365-settings/generate-certificate`.
///
/// The generated certificate's private key is never returned to the
/// client, so this endpoint saves the settings itself rather than handing
/// the PFX back for a later `PUT` — it needs [tenantId]/[clientId] up
/// front for that save, same as `SaveO365SyncSettingsRequest`.
class GenerateO365CertificateRequest {
  final String tenantId;
  final String clientId;
  final String password;

  const GenerateO365CertificateRequest({
    required this.tenantId,
    required this.clientId,
    required this.password,
  });

  factory GenerateO365CertificateRequest.fromJson(Map<String, dynamic> json) {
    final tenantId = json['tenantId'];
    final clientId = json['clientId'];
    final password = json['password'];

    if (tenantId is! String) {
      throw const FormatException('tenantId must be a string');
    }
    if (clientId is! String) {
      throw const FormatException('clientId must be a string');
    }
    if (password is! String) {
      throw const FormatException('password must be a string');
    }

    return GenerateO365CertificateRequest(
      tenantId: tenantId,
      clientId: clientId,
      password: password,
    );
  }
}
