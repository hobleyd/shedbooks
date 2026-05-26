import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/aba_sequence/get_next_aba_sequence_use_case.dart';
import '../audit_changes.dart';

/// Shelf request handlers for the /aba-sequences resource.
class AbaSequenceHandler {
  final GetNextAbaSequenceUseCase _nextSequence;

  const AbaSequenceHandler({required GetNextAbaSequenceUseCase nextSequence})
      : _nextSequence = nextSequence;

  /// POST /aba-sequences/next — returns the next daily sequence number for the authenticated entity.
  ///
  /// Accepts an optional JSON body `{ "references": ["P-26001", ...] }` listing the
  /// payment receipt numbers included in the ABA file; these are written to the audit log.
  Future<Response> handleNext(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> body;
    try {
      final raw = await request.readAsString();
      body = raw.isNotEmpty
          ? jsonDecode(raw) as Map<String, dynamic>
          : const {};
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final references = (body['references'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();

    final sequence = await _nextSequence.execute(entityId);

    (request.context['audit.changes'] as AuditChanges?)?.set({
      'sequence': sequence,
      if (references != null) 'references': references,
    });

    return Response.ok(
      jsonEncode({'sequence': sequence}),
      headers: _jsonHeaders,
    );
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
