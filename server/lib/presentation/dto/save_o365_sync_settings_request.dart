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

/// Request DTO for creating or updating O365 sync settings.
///
/// [certificatePfxBase64] and [certificatePassword] are each optional —
/// omit or send blank to keep the previously saved value unchanged.
class SaveO365SyncSettingsRequest {
  final String tenantId;
  final String clientId;
  final String? certificatePfxBase64;
  final String? certificatePassword;

  const SaveO365SyncSettingsRequest({
    required this.tenantId,
    required this.clientId,
    this.certificatePfxBase64,
    this.certificatePassword,
  });

  factory SaveO365SyncSettingsRequest.fromJson(Map<String, dynamic> json) {
    final tenantId = json['tenantId'];
    final clientId = json['clientId'];
    final certificatePfxBase64 = json['certificatePfxBase64'];
    final certificatePassword = json['certificatePassword'];

    if (tenantId is! String) {
      throw const FormatException('tenantId must be a string');
    }
    if (clientId is! String) {
      throw const FormatException('clientId must be a string');
    }
    if (certificatePfxBase64 != null && certificatePfxBase64 is! String) {
      throw const FormatException('certificatePfxBase64 must be a string');
    }
    if (certificatePassword != null && certificatePassword is! String) {
      throw const FormatException('certificatePassword must be a string');
    }

    return SaveO365SyncSettingsRequest(
      tenantId: tenantId,
      clientId: clientId,
      certificatePfxBase64: certificatePfxBase64 as String?,
      certificatePassword: certificatePassword as String?,
    );
  }
}
