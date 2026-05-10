import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/audit/list_audit_entries_use_case.dart';
import '../../domain/entities/audit_entry.dart';

/// Shelf request handlers for the /admin/audit-log resource.
class AuditHandler {
  final ListAuditEntriesUseCase _list;

  const AuditHandler({required ListAuditEntriesUseCase list}) : _list = list;

  /// GET /admin/audit-log?search=...&page=N
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final params = request.url.queryParameters;
    final search = params['search'];
    final page = int.tryParse(params['page'] ?? '1') ?? 1;

    final result = await _list.execute(
      entityId: entityId,
      search: search,
      page: page,
    );

    return Response.ok(
      jsonEncode({
        'entries': result.entries.map(_toJson).toList(),
        'total': result.total,
        'page': result.page,
        'limit': ListAuditEntriesUseCase.pageSize,
      }),
      headers: _jsonHeaders,
    );
  }

  static Map<String, dynamic> _toJson(AuditEntry e) => {
        'id': e.id,
        'userId': e.userId,
        'userEmail': e.userEmail,
        'ipAddress': e.ipAddress,
        'method': e.method,
        'path': e.path,
        'action': e.action,
        'tableName': e.tableName,
        'recordId': e.recordId,
        'statusCode': e.statusCode,
        'changes': e.changes,
        'createdAt': e.createdAt.toUtc().toIso8601String(),
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
