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

import 'package:shelf/shelf.dart';

import '../../domain/enums/app_role.dart';
import '../../domain/enums/permission_access.dart';
import '../../domain/enums/permission_action.dart';
import '../../domain/enums/permission_page.dart';
import '../../domain/repositories/i_role_permission_repository.dart';
import '../request_identity.dart';

/// Extracts the authenticated user's role from the request context.
///
/// Roles are read from the `https://shedbooks.com/roles` claim — normalised
/// into this key from Entra's own App Roles claim by [EntraJwtVerifier]
/// before it ever reaches here (see multi_issuer_jwt.dart). Defaults to
/// [AppRole.viewer] when the claim is absent so that no privilege is
/// granted by omission.
AppRole roleFromRequest(Request request) {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  final raw = claims?['https://shedbooks.com/roles'];
  final roles = raw is List ? raw : <dynamic>[];
  return AppRole.fromClaims(roles);
}

/// Middleware that returns 403 unless the caller's role has [access] on
/// [page], as resolved by [repository] (entity override, else global
/// default, else deny — see migration 062_add_role_permissions.sql).
Middleware requirePagePermission(
  IRolePermissionRepository repository,
  PermissionPage page,
  PermissionAccess access,
) =>
    _guard((entityId, role) async {
      final permissions =
          await repository.getEffective(entityId: entityId, role: role);
      return access == PermissionAccess.read
          ? permissions.canRead(page)
          : permissions.canWrite(page);
    });

/// Middleware that returns 403 unless the caller is at least
/// [AppRole.contributor].
///
/// Deliberately NOT migrated to [requirePagePermission] — this guards
/// `/api-key`, a personal CardDAV-sync credential reachable from the user
/// menu rather than any page in the Roles registry, so it isn't governed by
/// "which pages can this role access."
Middleware requireContributor() => _guard(
      (_, role) async => role.atLeast(AppRole.contributor),
    );

/// Middleware that returns 403 unless the caller's role can perform
/// [action] — an explicit override if one exists, else the action's own
/// page's write permission (see [EffectivePermissions.canPerform]).
Middleware requireActionPermission(
  IRolePermissionRepository repository,
  PermissionAction action,
) =>
    _guard((entityId, role) async {
      final permissions =
          await repository.getEffective(entityId: entityId, role: role);
      return permissions.canPerform(action);
    });

// ── Private ────────────────────────────────────────────────────────────────

Middleware _guard(Future<bool> Function(String entityId, AppRole role) isAllowed) {
  return (Handler inner) => (Request request) async {
        final entityId = resolveEntityId(request);
        if (entityId == null) return _forbidden();
        final role = roleFromRequest(request);
        if (!await isAllowed(entityId, role)) return _forbidden();
        return inner(request);
      };
}

Response _forbidden() => Response.forbidden(
      jsonEncode({'error': 'Insufficient permissions'}),
      headers: {'content-type': 'application/json'},
    );
