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

import '../../application/api_key/generate_api_key_use_case.dart';
import '../../application/api_key/get_api_key_status_use_case.dart';
import '../audit_changes.dart';

/// Shelf request handlers for the /api-key resource.
///
/// Provides two endpoints available to contributor and administrator roles:
/// - `GET /api-key`          — returns whether the user has an active API key.
/// - `POST /api-key/generate` — generates (or regenerates) the user's API key,
///   returning the raw value once.
class ApiKeyHandler {
  final GetApiKeyStatusUseCase _getStatus;
  final GenerateApiKeyUseCase _generate;

  const ApiKeyHandler({
    required GetApiKeyStatusUseCase getStatus,
    required GenerateApiKeyUseCase generate,
  })  : _getStatus = getStatus,
        _generate = generate;

  /// GET /api-key — returns `{"hasKey": bool, "username": email}`.
  Future<Response> handleGetStatus(Request request) async {
    final (entityId, userId, userEmail) = _userContext(request);
    if (entityId == null || userId == null) return _orgRequired();

    final result = await _getStatus.execute(
      entityId: entityId,
      userId: userId,
      userEmail: userEmail,
    );

    return Response.ok(
      jsonEncode({'hasKey': result.hasKey, 'username': result.username}),
      headers: _jsonHeaders,
    );
  }

  /// POST /api-key/generate — generates a new key; returns the raw value once.
  ///
  /// The response body is `{"apiKey": "<raw>", "username": email}`.
  /// The raw key is never stored and cannot be retrieved after this call.
  Future<Response> handleGenerate(Request request) async {
    final (entityId, userId, userEmail) = _userContext(request);
    if (entityId == null || userId == null) return _orgRequired();

    final result = await _generate.execute(
      entityId: entityId,
      userId: userId,
      userEmail: userEmail,
    );

    _auditChanges(request)?.set({'action': 'generated', 'username': userEmail});

    return Response.ok(
      jsonEncode({'apiKey': result.apiKey, 'username': result.username}),
      headers: _jsonHeaders,
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  static (String?, String?, String) _userContext(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    final entityId = claims?['https://shedbooks.com/entity_id'] as String?;
    final userId = claims?['sub'] as String?;
    final userEmail =
        (claims?['email'] as String?)?.isNotEmpty == true
            ? claims!['email'] as String
            : (claims?['https://shedbooks.com/email'] as String?) ?? '';
    return (entityId, userId, userEmail);
  }

  static AuditChanges? _auditChanges(Request r) =>
      r.context['audit.changes'] as AuditChanges?;

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
