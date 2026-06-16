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

import '../../application/users/list_active_users_use_case.dart';
import '../../domain/entities/user_presence.dart';

/// Shelf request handlers for the /admin/users resource.
class UsersHandler {
  final ListActiveUsersUseCase _list;

  const UsersHandler({required ListActiveUsersUseCase list}) : _list = list;

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

  static Map<String, dynamic> _toJson(UserPresence p) => {
        'userId': p.userId,
        'userEmail': p.userEmail,
        'role': p.role,
        'lastSeen': p.lastSeen.toUtc().toIso8601String(),
        'ipAddress': p.ipAddress,
      };

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
