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

import '../entities/effective_permissions.dart';
import '../entities/role_permission_matrix.dart';
import '../enums/app_role.dart';
import '../enums/permission_action.dart';
import '../enums/permission_page.dart';

/// A page's desired (page, role) override state, as submitted by a Roles-page save.
typedef PagePermissionOverride = ({
  PermissionPage page,
  AppRole role,
  bool canRead,
  bool canWrite,
});

/// An action's desired (action, role) override state, as submitted by a Roles-page save.
typedef ActionPermissionOverride = ({
  PermissionAction action,
  AppRole role,
  bool canPerform,
});

/// Contract for reading and writing the role/page/action permission matrix.
///
/// Implementations resolve effective permissions via: entity override, else
/// global default, else deny (and, one level further for actions: the
/// action's own page's write permission before deny). See migration
/// 062_add_role_permissions.sql for the underlying table shapes and the
/// template-entity mechanism referenced by [save].
abstract interface class IRolePermissionRepository {
  /// Resolved, flattened permissions for [role] within [entityId]. Callers
  /// (principally the `requirePagePermission`/`requireActionPermission`
  /// route guards) should treat this as cheap — implementations are
  /// expected to cache it and invalidate on [save].
  Future<EffectivePermissions> getEffective({
    required String entityId,
    required AppRole role,
  });

  /// The full editable matrix (every page/action, every role) for the Roles
  /// admin screen, including whether [entityId] is the template entity and,
  /// per cell, whether it's an explicit override or inherited.
  Future<RolePermissionMatrix> getMatrix(String entityId);

  /// Replaces the complete override state for [entityId] with exactly
  /// [pages] and [actions] — any existing override not present in either
  /// list is deleted (reset to "inherit"). Writes to the global defaults
  /// tables instead of entity-scoped rows when [entityId] is the template
  /// entity (see `entity_details.is_template_entity`).
  Future<void> save({
    required String entityId,
    required List<PagePermissionOverride> pages,
    required List<ActionPermissionOverride> actions,
  });
}
