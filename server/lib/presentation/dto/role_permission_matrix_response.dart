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

import '../../domain/entities/role_permission_matrix.dart';

/// JSON response shape for GET /roles/permissions.
class RolePermissionMatrixResponse {
  final bool isTemplateEntity;
  final List<PagePermissionCell> pages;
  final List<ActionPermissionCell> actions;

  const RolePermissionMatrixResponse({
    required this.isTemplateEntity,
    required this.pages,
    required this.actions,
  });

  factory RolePermissionMatrixResponse.fromEntity(RolePermissionMatrix matrix) =>
      RolePermissionMatrixResponse(
        isTemplateEntity: matrix.isTemplateEntity,
        pages: matrix.pages,
        actions: matrix.actions,
      );

  Map<String, dynamic> toJson() => {
        'isTemplateEntity': isTemplateEntity,
        'pages': [
          for (final p in pages)
            {
              'page': p.page.key,
              'role': p.role.name,
              'canRead': p.canRead,
              'canWrite': p.canWrite,
              'isOverride': p.isOverride,
            },
        ],
        'actions': [
          for (final a in actions)
            {
              'action': a.action.key,
              'role': a.role.name,
              'canPerform': a.canPerform,
              'isOverride': a.isOverride,
            },
        ],
      };

  String toJsonString() => jsonEncode(toJson());
}
