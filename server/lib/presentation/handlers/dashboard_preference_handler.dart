import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/dashboard/get_dashboard_preference_use_case.dart';
import '../../application/dashboard/save_dashboard_preference_use_case.dart';
import '../../domain/entities/dashboard_preference.dart';
import '../dto/dashboard_preference_response.dart';

/// Shelf request handlers for /dashboard-preferences.
class DashboardPreferenceHandler {
  final GetDashboardPreferenceUseCase _get;
  final SaveDashboardPreferenceUseCase _save;

  const DashboardPreferenceHandler({
    required GetDashboardPreferenceUseCase get,
    required SaveDashboardPreferenceUseCase save,
  })  : _get = get,
        _save = save;

  /// GET /dashboard-preferences
  Future<Response> handleGet(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final pref = await _get.execute(entityId);
    return Response.ok(
      DashboardPreferenceResponse.fromEntity(pref).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// PUT /dashboard-preferences
  Future<Response> handleSave(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final List<GlAccountPair> pairs;
    try {
      final rawList = json['selectedAccountPairs'] as List;
      pairs = rawList.map((e) {
        final m = e as Map<String, dynamic>;
        return GlAccountPair(
          incomeGlId: m['incomeGlId'] as String,
          expenseGlId: m['expenseGlId'] as String,
        );
      }).toList();
    } catch (_) {
      return _badRequest(
          'selectedAccountPairs must be a list of {incomeGlId, expenseGlId} objects');
    }

    await _save.execute(entityId, pairs);
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
