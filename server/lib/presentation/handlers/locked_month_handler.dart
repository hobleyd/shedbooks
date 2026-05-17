import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/locked_month/list_locked_months_use_case.dart';
import '../../application/locked_month/lock_month_use_case.dart';
import '../../application/locked_month/unlock_month_use_case.dart';
import '../dto/lock_month_request.dart';
import '../dto/locked_month_response.dart';

/// Shelf request handlers for the /locked-months resource.
class LockedMonthHandler {
  final ListLockedMonthsUseCase _list;
  final LockMonthUseCase _lock;
  final UnlockMonthUseCase _unlock;

  const LockedMonthHandler({
    required ListLockedMonthsUseCase list,
    required LockMonthUseCase lock,
    required UnlockMonthUseCase unlock,
  })  : _list = list,
        _lock = lock,
        _unlock = unlock;

  /// GET /locked-months
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final months = await _list.execute(entityId);
    return Response.ok(
      LockedMonthResponse.toJsonList(months),
      headers: _jsonHeaders,
    );
  }

  /// POST /locked-months
  Future<Response> handleLock(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final LockMonthRequest dto;
    try {
      dto = LockMonthRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _lock.execute(entityId, dto.monthYear);
    } on ArgumentError catch (e) {
      return _badRequest(e.message.toString());
    }

    return Response(204);
  }

  /// DELETE /locked-months/:monthYear
  Future<Response> handleUnlock(Request request, String monthYear) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    await _unlock.execute(entityId, monthYear);
    return Response(204);
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
