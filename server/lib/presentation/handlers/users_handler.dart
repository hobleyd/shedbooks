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
