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
import 'o365_sync_settings_response.dart';

/// Response DTO for `POST /admin/o365-settings/generate-certificate`.
///
/// The private key never leaves the server: this endpoint generates the
/// certificate and saves it in the same request, then returns the saved
/// [settings] plus the certificate's public half ([publicCertBase64]) for
/// the admin to download and upload to Azure. There is no
/// `certificatePfxBase64` field here — unlike an admin-supplied `.pfx`
/// upload, a server-generated private key has no legitimate reason to ever
/// cross the wire to the browser.
class GenerateO365CertificateResponse {
  final O365SyncSettingsResponse settings;
  final String publicCertBase64;

  const GenerateO365CertificateResponse({
    required this.settings,
    required this.publicCertBase64,
  });

  factory GenerateO365CertificateResponse.fromResult({
    required O365SyncSettings settings,
    required String publicCertBase64,
  }) =>
      GenerateO365CertificateResponse(
        settings: O365SyncSettingsResponse.fromEntity(settings),
        publicCertBase64: publicCertBase64,
      );

  Map<String, dynamic> toJson() => {
        ...settings.toJson(),
        'publicCertBase64': publicCertBase64,
      };

  String toJsonString() => jsonEncode(toJson());
}
