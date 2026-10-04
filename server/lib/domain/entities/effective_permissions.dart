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

import '../enums/permission_action.dart';
import '../enums/permission_page.dart';

/// A single role's fully-resolved read/write access to every page and
/// action within one entity — the result of walking the resolution chain
/// (entity override, else global default, else deny) once so that request
/// handling is a cheap map lookup. See [IRolePermissionRepository.getEffective].
class EffectivePermissions {
  final Map<PermissionPage, ({bool canRead, bool canWrite})> _pages;
  final Map<PermissionAction, bool> _actions;

  const EffectivePermissions({
    required Map<PermissionPage, ({bool canRead, bool canWrite})> pages,
    required Map<PermissionAction, bool> actions,
  })  : _pages = pages,
        _actions = actions;

  bool canRead(PermissionPage page) => _pages[page]?.canRead ?? false;

  bool canWrite(PermissionPage page) => _pages[page]?.canWrite ?? false;

  /// Falls back to the action's own page's write permission when no
  /// resolved action entry exists (i.e. this action has never diverged from
  /// its page for this role/entity) — the literal "inherits from the page"
  /// behaviour.
  bool canPerform(PermissionAction action) =>
      _actions[action] ?? canWrite(action.page);

  /// Flattened view for the `/roles/effective` response — every page and
  /// action key this role can see anything of, keyed by their string [key]s.
  Map<String, dynamic> toJson() => {
        'pages': {
          for (final page in PermissionPage.values)
            page.key: {'canRead': canRead(page), 'canWrite': canWrite(page)},
        },
        'actions': {
          for (final action in PermissionAction.values)
            action.key: canPerform(action),
        },
      };
}
