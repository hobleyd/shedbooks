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

import '../entities/o365_sync_settings.dart';
import '../exceptions/app_role_exception.dart';

/// Grants or revokes a Shedbooks app role (viewer/contributor/administrator)
/// on a tenant user's Entra ID account, via Microsoft Graph.
///
/// Reuses the same certificate-based app-only credentials as
/// [O365SyncSettings] (the "Shedbooks O365 Sync" app registration) rather
/// than a separate credential — that app registration must additionally
/// hold the Graph *application* permission `AppRoleAssignment.ReadWrite.All`
/// with admin consent; see manage_app_role_assignment.ps1's header.
abstract interface class IGraphAppRoleService {
  /// Ensures [targetUserId] (an Entra UPN or object id) holds exactly
  /// [appRole] on the Shedbooks Login application's service principal
  /// ([resourceServicePrincipalId]) — any other role assignment for that
  /// resource is removed first. Pass `null` for [appRole] to revoke access
  /// entirely.
  ///
  /// Returns the role actually in effect immediately after the change, as
  /// read back from Graph — not necessarily [appRole], if Graph's state
  /// unexpectedly still differs (e.g. a concurrent change). Callers should
  /// persist this returned value, not the requested one.
  ///
  /// Throws [GraphAppRoleException] if the Graph session itself fails, or
  /// [targetUserId] cannot be resolved to a user in the tenant.
  Future<String?> setAppRole({
    required O365SyncSettings settings,
    required String resourceServicePrincipalId,
    required String targetUserId,
    required String? appRole,
  });
}
