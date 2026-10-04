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

import '../../domain/enums/app_role.dart';
import '../../domain/enums/permission_action.dart';
import '../../domain/enums/permission_page.dart';
import '../../domain/exceptions/role_permission_exception.dart';
import '../../domain/repositories/i_entity_details_repository.dart';
import '../../domain/repositories/i_role_permission_repository.dart';

/// Persists a Roles-page save, after checking it can't lock every
/// administrator out of the Roles page itself, and — for the template
/// entity — can't silently widen a cell by omitting it.
///
/// [IRolePermissionRepository.save] fully replaces the target table's rows
/// (global defaults for the template entity, this entity's overrides
/// otherwise) with exactly what's submitted — so the two cases need
/// different validation:
///  - Template entity: the submitted [pages]/[actions] lists *become* the
///    entire global defaults tables, so every page/role and action/role
///    combination must be present explicitly (see
///    [IncompleteRoleDefaultsException]) — including administrator read+write
///    on the Roles page, or that row simply won't exist afterwards (denying
///    every entity that hasn't overridden it).
///  - Any other entity: an *absent* entry is safe — it falls back to the
///    (fully-populated, equally protected) global default. Only an explicit
///    Roles-page entry that denies read or write is a problem.
class SaveRolePermissionsUseCase {
  final IRolePermissionRepository _repository;
  final IEntityDetailsRepository _entityDetailsRepository;

  const SaveRolePermissionsUseCase(
    this._repository,
    this._entityDetailsRepository,
  );

  /// Throws [RolesSelfLockoutException] if the proposed state would leave
  /// `administrator` without both read and write on the Roles page.
  Future<void> execute({
    required String entityId,
    required List<PagePermissionOverride> pages,
    required List<ActionPermissionOverride> actions,
  }) async {
    final isTemplate = await _entityDetailsRepository.isTemplateEntity(entityId);

    if (isTemplate) {
      final expectedPageCount = PermissionPage.values.length * AppRole.values.length;
      final expectedActionCount = PermissionAction.values.length * AppRole.values.length;
      if (pages.length != expectedPageCount || actions.length != expectedActionCount) {
        throw const IncompleteRoleDefaultsException();
      }
    }

    final adminRolesEntries = pages.where(
      (p) => p.page == PermissionPage.adminRoles && p.role == AppRole.administrator,
    );
    final explicit = adminRolesEntries.isEmpty ? null : adminRolesEntries.first;

    final grantsFullAccess = explicit != null && explicit.canRead && explicit.canWrite;

    if (isTemplate && !grantsFullAccess) {
      throw const RolesSelfLockoutException();
    }
    if (!isTemplate && explicit != null && !grantsFullAccess) {
      throw const RolesSelfLockoutException();
    }

    await _repository.save(entityId: entityId, pages: pages, actions: actions);
  }
}
