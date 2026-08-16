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

import 'o365_sync_settings.dart';

/// Result of a server-generated self-signed certificate that the server has
/// already saved as this entity's O365 sync settings.
///
/// There is no private-key field here — the server never returns the PFX
/// it generates, only [publicCertBase64], which the admin downloads and
/// uploads to Azure. [settings] reflects the already-persisted state, same
/// shape as a normal settings save.
class GeneratedO365Certificate {
  final O365SyncSettings settings;
  final String publicCertBase64;

  const GeneratedO365Certificate({
    required this.settings,
    required this.publicCertBase64,
  });

  factory GeneratedO365Certificate.fromJson(Map<String, dynamic> json) =>
      GeneratedO365Certificate(
        settings: O365SyncSettings.fromJson(json),
        publicCertBase64: json['publicCertBase64'] as String,
      );
}
