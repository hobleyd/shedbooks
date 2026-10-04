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

import '../enums/app_role.dart';
import '../enums/permission_action.dart';
import '../enums/permission_page.dart';

/// One (page, role) cell of the editable matrix shown on the Roles screen.
class PagePermissionCell {
  final PermissionPage page;
  final AppRole role;
  final bool canRead;
  final bool canWrite;

  /// True when this entity (or, for the template entity, the global
  /// defaults table itself) has an explicit row for this cell, rather than
  /// falling back through the resolution chain.
  final bool isOverride;

  const PagePermissionCell({
    required this.page,
    required this.role,
    required this.canRead,
    required this.canWrite,
    required this.isOverride,
  });
}

/// One (action, role) cell of the editable matrix shown on the Roles screen.
class ActionPermissionCell {
  final PermissionAction action;
  final AppRole role;
  final bool canPerform;
  final bool isOverride;

  const ActionPermissionCell({
    required this.action,
    required this.role,
    required this.canPerform,
    required this.isOverride,
  });
}

/// The full editable permission matrix for one entity's Roles screen: every
/// page and action, for every role, with enough provenance (`isOverride`) to
/// show the admin what's inherited vs. explicitly set.
class RolePermissionMatrix {
  /// Whether saving from this entity writes to the global defaults tables
  /// (becoming the baseline for future entities) rather than this entity's
  /// own override tables.
  final bool isTemplateEntity;
  final List<PagePermissionCell> pages;
  final List<ActionPermissionCell> actions;

  const RolePermissionMatrix({
    required this.isTemplateEntity,
    required this.pages,
    required this.actions,
  });
}
