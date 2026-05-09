import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';

import '../../application/contact/lookup_abn_use_case.dart';

/// Shelf handler for ABN lookups against the Australian Business Register.
class AbnLookupHandler {
  final LookupAbnUseCase _lookup;

  const AbnLookupHandler({required LookupAbnUseCase lookup}) : _lookup = lookup;

  /// GET /abn-lookup?abn=XXXXXXXXXXX
  ///
  /// Returns `{ "found": bool, "gstRegistered": bool }`.
  Future<Response> handle(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );
    }

    final abn = request.url.queryParameters['abn'];
    if (abn == null || !RegExp(r'^\d{11}$').hasMatch(abn)) {
      return Response(
        400,
        body: jsonEncode({'error': 'abn query parameter must be exactly 11 digits'}),
        headers: _jsonHeaders,
      );
    }

    try {
      final result = await _lookup.execute(abn);
      return Response.ok(
        jsonEncode({
          'found': result.found,
          'gstRegistered': result.gstRegistered,
        }),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response(
        502,
        body: jsonEncode({'error': 'ABN lookup failed: $e'}),
        headers: _jsonHeaders,
      );
    }
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
