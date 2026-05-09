import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';

import '../../application/gst_rate/create_gst_rate_use_case.dart';
import '../../application/gst_rate/delete_gst_rate_use_case.dart';
import '../../application/gst_rate/get_effective_gst_rate_use_case.dart';
import '../../application/gst_rate/get_gst_rate_use_case.dart';
import '../../application/gst_rate/list_gst_rates_use_case.dart';
import '../../application/gst_rate/update_gst_rate_use_case.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../dto/create_gst_rate_request.dart';
import '../dto/gst_rate_response.dart';
import '../dto/update_gst_rate_request.dart';

/// Shelf request handlers for the /gst-rates resource.
class GstRateHandler {
  final CreateGstRateUseCase _create;
  final GetGstRateUseCase _get;
  final ListGstRatesUseCase _list;
  final UpdateGstRateUseCase _update;
  final DeleteGstRateUseCase _delete;
  final GetEffectiveGstRateUseCase _getEffective;

  const GstRateHandler({
    required CreateGstRateUseCase create,
    required GetGstRateUseCase get,
    required ListGstRatesUseCase list,
    required UpdateGstRateUseCase update,
    required DeleteGstRateUseCase delete,
    required GetEffectiveGstRateUseCase getEffective,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _getEffective = getEffective;

  /// GET /gst-rates
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final rates = await _list.execute(entityId: entityId);
    final body = jsonEncode(
      rates.map((r) => GstRateResponse.fromEntity(r).toJson()).toList(),
    );
    return Response.ok(body, headers: _jsonHeaders);
  }

  /// POST /gst-rates
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final CreateGstRateRequest dto;
    try {
      dto = CreateGstRateRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final rate = await _create.execute(
        entityId: entityId,
        rate: dto.rate,
        effectiveFrom: dto.effectiveFrom,
      );
      return Response(
        201,
        body: GstRateResponse.fromEntity(rate).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GstRateValidationException catch (e) {
      return _badRequest(e.message);
    } on GstRateDuplicateEffectiveDateException catch (e) {
      return Response(409, body: jsonEncode({'error': e.message}), headers: _jsonHeaders);
    }
  }

  /// GET /gst-rates/effective?at=<iso8601>
  Future<Response> handleGetEffective(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    DateTime? at;
    final atParam = request.url.queryParameters['at'];
    if (atParam != null) {
      try {
        at = DateTime.parse(atParam).toUtc();
      } on FormatException {
        return _badRequest('at must be a valid ISO 8601 date/time');
      }
    }

    try {
      final rate = await _getEffective.execute(entityId: entityId, date: at);
      return Response.ok(
        GstRateResponse.fromEntity(rate).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GstRateNotEffectiveException catch (e) {
      return _notFound(e.message);
    }
  }

  /// GET /gst-rates/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    try {
      final rate = await _get.execute(id, entityId: entityId);
      return Response.ok(
        GstRateResponse.fromEntity(rate).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GstRateNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /gst-rates/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final UpdateGstRateRequest dto;
    try {
      dto = UpdateGstRateRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final rate = await _update.execute(
        id: id,
        entityId: entityId,
        rate: dto.rate,
        effectiveFrom: dto.effectiveFrom,
      );
      return Response.ok(
        GstRateResponse.fromEntity(rate).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GstRateNotFoundException catch (e) {
      return _notFound(e.message);
    } on GstRateValidationException catch (e) {
      return _badRequest(e.message);
    } on GstRateDuplicateEffectiveDateException catch (e) {
      return Response(409, body: jsonEncode({'error': e.message}), headers: _jsonHeaders);
    }
  }

  /// DELETE /gst-rates/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    try {
      await _delete.execute(id, entityId: entityId);
      return Response(204);
    } on GstRateNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

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

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _notFound(String message) => Response.notFound(
        jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );
}
