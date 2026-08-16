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

import '../../domain/entities/o365_sync_settings.dart';

/// Response DTO for O365 sync settings.
///
/// The certificate and its password are deliberately never included — they
/// are write-only. [certificateConfigured] tells the UI whether one has
/// been saved, so the edit form can show "leave blank to keep the current
/// certificate".
class O365SyncSettingsResponse {
  final String tenantId;
  final String clientId;
  final bool certificateConfigured;
  final bool autoSyncEnabled;
  final String? certificateExpiresAt;

  const O365SyncSettingsResponse({
    required this.tenantId,
    required this.clientId,
    required this.certificateConfigured,
    required this.autoSyncEnabled,
    this.certificateExpiresAt,
  });

  factory O365SyncSettingsResponse.fromEntity(O365SyncSettings e) =>
      O365SyncSettingsResponse(
        tenantId: e.tenantId,
        clientId: e.clientId,
        certificateConfigured: e.certificatePfxBase64.isNotEmpty,
        autoSyncEnabled: e.autoSyncEnabled,
        certificateExpiresAt: e.certificateExpiresAt?.toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'tenantId': tenantId,
        'clientId': clientId,
        'certificateConfigured': certificateConfigured,
        'autoSyncEnabled': autoSyncEnabled,
        'certificateExpiresAt': certificateExpiresAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
