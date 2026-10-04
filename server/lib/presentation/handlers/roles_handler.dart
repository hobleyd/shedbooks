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
import 'dart:io';
import 'package:shelf/shelf.dart';
import '../request_identity.dart';

import '../../application/roles/get_effective_permissions_use_case.dart';
import '../../application/roles/get_role_permissions_use_case.dart';
import '../../application/roles/save_role_permissions_use_case.dart';
import '../../domain/exceptions/role_permission_exception.dart';
import '../../presentation/middleware/role_guard.dart';
import '../audit_changes.dart';
import '../dto/role_permission_matrix_response.dart';
import '../dto/role_permission_save_request.dart';

/// Shelf request handlers for the /roles resource.
class RolesHandler {
  final GetRolePermissionsUseCase _get;
  final SaveRolePermissionsUseCase _save;
  final GetEffectivePermissionsUseCase _getEffective;

  const RolesHandler({
    required GetRolePermissionsUseCase get,
    required SaveRolePermissionsUseCase save,
    required GetEffectivePermissionsUseCase getEffective,
  })  : _get = get,
        _save = save,
        _getEffective = getEffective;

  /// GET /roles/permissions
  Future<Response> handleGetPermissions(Request request) async {
    final entityId = resolveEntityId(request);
    if (entityId == null) return _orgRequired();

    final matrix = await _get.execute(entityId);
    return Response.ok(
      RolePermissionMatrixResponse.fromEntity(matrix).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// PUT /roles/permissions
  Future<Response> handleSavePermissions(Request request) async {
    final entityId = resolveEntityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final RolePermissionSaveRequest dto;
    try {
      dto = RolePermissionSaveRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _save.execute(entityId: entityId, pages: dto.pages, actions: dto.actions);
      _auditChanges(request)?.set({
        'pages': [
          for (final p in dto.pages)
            {'page': p.page.key, 'role': p.role.name, 'canRead': p.canRead, 'canWrite': p.canWrite},
        ],
        'actions': [
          for (final a in dto.actions)
            {'action': a.action.key, 'role': a.role.name, 'canPerform': a.canPerform},
        ],
      });
      return Response(204);
    } on RolesSelfLockoutException catch (e) {
      return _badRequest(e.message);
    } on IncompleteRoleDefaultsException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /roles/effective
  Future<Response> handleGetEffective(Request request) async {
    final entityId = resolveEntityId(request);
    if (entityId == null) return _orgRequired();

    final role = roleFromRequest(request);
    final permissions = await _getEffective.execute(entityId: entityId, role: role);
    return Response.ok(jsonEncode(permissions.toJson()), headers: _jsonHeaders);
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );
}
