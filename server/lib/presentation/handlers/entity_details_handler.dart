import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/entity/get_entity_details_use_case.dart';
import '../../application/entity/save_entity_details_use_case.dart';
import '../../domain/entities/entity_details.dart';
import '../../domain/enums/app_role.dart';
import '../../domain/exceptions/entity_details_exception.dart';
import '../audit_changes.dart';
import '../dto/entity_details_response.dart';
import '../dto/save_entity_details_request.dart';
import 'handler_diff.dart';

/// Shelf request handlers for /entity-details.
class EntityDetailsHandler {
  final GetEntityDetailsUseCase _get;
  final SaveEntityDetailsUseCase _save;

  const EntityDetailsHandler({
    required GetEntityDetailsUseCase get,
    required SaveEntityDetailsUseCase save,
  })  : _get = get,
        _save = save;

  /// GET /entity-details — returns 404 when not yet configured.
  Future<Response> handleGet(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final role = _userRole(request);
    final isAuthorized = role.atLeast(AppRole.administrator);

    try {
      final details = await _get.execute(entityId);
      final result = isAuthorized ? details : _redact(details);
      return Response.ok(
        EntityDetailsResponse.fromEntity(result).toJsonString(),
        headers: _jsonHeaders,
      );
    } on EntityDetailsNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /entity-details — creates or updates.
  Future<Response> handleSave(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final SaveEntityDetailsRequest dto;
    try {
      dto = SaveEntityDetailsRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    EntityDetails? before;
    try {
      before = await _get.execute(entityId);
    } catch (_) {}

    try {
      final details = await _save.execute(
        entityId: entityId,
        name: dto.name,
        abn: dto.abn,
        incorporationIdentifier: dto.incorporationIdentifier,
        apcaId: dto.apcaId,
        moneyInReceiptFormat: dto.moneyInReceiptFormat,
        moneyOutReceiptFormat: dto.moneyOutReceiptFormat,
      );
      if (before == null) {
        _auditChanges(request)?.set(_detailsSnapshot(details));
      } else {
        final diff = diffMaps(_detailsSnapshot(before), _detailsSnapshot(details));
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      return Response.ok(
        EntityDetailsResponse.fromEntity(details).toJsonString(),
        headers: _jsonHeaders,
      );
    } on EntityDetailsValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AppRole _userRole(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    final roles = claims?['https://shedbooks.com/roles'] as List<dynamic>? ?? [];
    return AppRole.fromClaims(roles);
  }

  static EntityDetails _redact(EntityDetails d) => EntityDetails(
        entityId: d.entityId,
        name: d.name,
        abn: d.abn,
        incorporationIdentifier: d.incorporationIdentifier,
        apcaId: null,
        moneyInReceiptFormat: d.moneyInReceiptFormat,
        moneyOutReceiptFormat: d.moneyOutReceiptFormat,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
      );

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Map<String, dynamic> _detailsSnapshot(EntityDetails d) => {
        'name': d.name,
        'abn': d.abn,
        'incorporationIdentifier': d.incorporationIdentifier,
        'apcaId': d.apcaId,
        'moneyInReceiptFormat': d.moneyInReceiptFormat,
        'moneyOutReceiptFormat': d.moneyOutReceiptFormat,
      };

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _notFound(String message) => Response.notFound(
        jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
