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

/// Microsoft 365 sync settings returned from the API.
///
/// The certificate and its password are never returned —
/// [certificateConfigured] tells the UI whether one has already been saved.
class O365SyncSettings {
  final String tenantId;
  final String clientId;
  final bool certificateConfigured;
  final bool autoSyncEnabled;
  final DateTime? certificateExpiresAt;

  const O365SyncSettings({
    required this.tenantId,
    required this.clientId,
    required this.certificateConfigured,
    required this.autoSyncEnabled,
    this.certificateExpiresAt,
  });

  factory O365SyncSettings.fromJson(Map<String, dynamic> json) =>
      O365SyncSettings(
        tenantId: json['tenantId'] as String,
        clientId: json['clientId'] as String,
        certificateConfigured: json['certificateConfigured'] as bool? ?? false,
        autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? false,
        certificateExpiresAt: json['certificateExpiresAt'] != null
            ? DateTime.parse(json['certificateExpiresAt'] as String)
            : null,
      );
}
