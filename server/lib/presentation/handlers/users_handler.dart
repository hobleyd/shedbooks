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

import '../../application/users/list_active_users_use_case.dart';
import '../../application/users/set_user_app_role_use_case.dart';
import '../../domain/entities/user_presence.dart';
import '../../domain/exceptions/app_role_exception.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../audit_changes.dart';
import '../dto/set_app_role_request.dart';

/// Shelf request handlers for the /admin/users resource.
class UsersHandler {
  final ListActiveUsersUseCase _list;
  final SetUserAppRoleUseCase _setAppRole;

  const UsersHandler({
    required ListActiveUsersUseCase list,
    required SetUserAppRoleUseCase setAppRole,
  })  : _list = list,
        _setAppRole = setAppRole;

  /// GET /admin/users — returns all presence records for the authenticated entity.
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final users = await _list.execute(entityId: entityId);

    return Response.ok(
      jsonEncode({'users': users.map(_toJson).toList()}),
      headers: _jsonHeaders,
    );
  }

  /// PUT /admin/users/:userId/role — grants, changes, or revokes a
  /// previously-signed-in user's Shedbooks access. [userId] is the target's
  /// Entra object id (`sub`/`oid` claim), as shown in the Users screen.
  ///
  /// The affected user's browser keeps using its current access token
  /// (which already has their old role baked in) until it next acquires a
  /// fresh one — a role change here does not take effect immediately for
  /// someone already signed in.
  Future<Response> handleSetRole(Request request, String userId) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final SetAppRoleRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = SetAppRoleRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    try {
      final role = await _setAppRole.execute(
        entityId: entityId,
        callerUserId: resolveUserId(request) ?? '',
        targetUserId: userId,
        appRole: dto.role,
      );
      _auditChanges(request)?.set({'userId': userId, 'role': role});
      return Response.ok(
        jsonEncode({'userId': userId, 'role': role}),
        headers: _jsonHeaders,
      );
    } on SelfRoleChangeException catch (e) {
      return _forbidden(e.message);
    } on O365SyncNotConfiguredException catch (e) {
      return _badRequest(e.message);
    } on GraphAppRoleException catch (e) {
      return _syncFailed(e.message);
    }
  }

  static Map<String, dynamic> _toJson(UserPresence p) => {
        'userId': p.userId,
        'userEmail': p.userEmail,
        'role': p.role,
        'lastSeen': p.lastSeen.toUtc().toIso8601String(),
        'ipAddress': p.ipAddress,
      };

  static String? _entityId(Request request) => resolveEntityId(request);

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _forbidden(String message) => Response.forbidden(
        jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _syncFailed(String message) => Response(
        502,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
