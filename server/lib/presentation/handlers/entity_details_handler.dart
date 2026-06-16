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

    final role = _userRole(request);
    final isAuthorized = role.atLeast(AppRole.administrator);

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
        apcaId: isAuthorized ? dto.apcaId : before?.apcaId,
        moneyInReceiptFormat: dto.moneyInReceiptFormat,
        moneyOutReceiptFormat: dto.moneyOutReceiptFormat,
      );
      if (before == null) {
        _auditChanges(request)?.set(_detailsSnapshot(details, redact: true));
      } else {
        final bSnap = _detailsSnapshot(before, redact: true);
        final aSnap = _detailsSnapshot(details, redact: true);
        final diff = diffMaps(bSnap, aSnap);
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      final result = isAuthorized ? details : _redact(details);
      return Response.ok(
        EntityDetailsResponse.fromEntity(result).toJsonString(),
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

  static Map<String, dynamic> _detailsSnapshot(EntityDetails d,
          {bool redact = false}) =>
      {
        'name': d.name,
        'abn': d.abn,
        'incorporationIdentifier': d.incorporationIdentifier,
        'apcaId': redact ? (d.apcaId != null ? '***' : null) : d.apcaId,
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
