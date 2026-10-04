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
import '../../domain/repositories/i_role_permission_repository.dart';

/// Deserialised request body for PUT /roles/permissions.
///
/// Represents the *complete* desired override state — any cell not listed
/// here resets to "inherit" (see [IRolePermissionRepository.save]).
class RolePermissionSaveRequest {
  final List<PagePermissionOverride> pages;
  final List<ActionPermissionOverride> actions;

  const RolePermissionSaveRequest({required this.pages, required this.actions});

  factory RolePermissionSaveRequest.fromJson(Map<String, dynamic> json) {
    final pagesRaw = json['pages'];
    final actionsRaw = json['actions'];
    if (pagesRaw is! List) throw const FormatException('pages must be a list');
    if (actionsRaw is! List) throw const FormatException('actions must be a list');

    return RolePermissionSaveRequest(
      pages: pagesRaw.map(_parsePage).toList(),
      actions: actionsRaw.map(_parseAction).toList(),
    );
  }

  static PagePermissionOverride _parsePage(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('each page entry must be an object');
    }
    final canRead = raw['canRead'];
    final canWrite = raw['canWrite'];
    if (canRead is! bool) throw const FormatException('canRead must be a boolean');
    if (canWrite is! bool) throw const FormatException('canWrite must be a boolean');

    return (
      page: PermissionPage.fromKey(_stringField(raw, 'page')),
      role: _parseRole(raw),
      canRead: canRead,
      canWrite: canWrite,
    );
  }

  static ActionPermissionOverride _parseAction(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('each action entry must be an object');
    }
    final canPerform = raw['canPerform'];
    if (canPerform is! bool) throw const FormatException('canPerform must be a boolean');

    return (
      action: PermissionAction.fromKey(_stringField(raw, 'action')),
      role: _parseRole(raw),
      canPerform: canPerform,
    );
  }

  static String _stringField(Map<String, dynamic> raw, String field) {
    final value = raw[field];
    if (value is! String) throw FormatException('$field must be a string');
    return value;
  }

  static AppRole _parseRole(Map<String, dynamic> raw) {
    final role = raw['role'];
    if (role is! String) throw const FormatException('role must be a string');
    try {
      return AppRole.values.byName(role);
    } on ArgumentError {
      throw FormatException('Unknown role: $role');
    }
  }
}
