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
import '../request_identity.dart';

import '../../application/capex_request/create_capex_request_use_case.dart';
import '../../application/capex_request/decide_capex_request_use_case.dart';
import '../../application/capex_request/delete_capex_request_use_case.dart';
import '../../application/capex_request/get_capex_request_use_case.dart';
import '../../application/capex_request/get_next_capex_request_no_use_case.dart';
import '../../application/capex_request/list_capex_requests_use_case.dart';
import '../../application/capex_request/set_capex_request_executed_date_use_case.dart';
import '../../application/capex_request/update_capex_request_use_case.dart';
import '../../domain/entities/capex_request.dart';
import '../../domain/exceptions/capex_request_exception.dart';
import '../audit_changes.dart';
import '../dto/capex_request_response.dart';
import '../dto/create_capex_request_request.dart';
import '../dto/decide_capex_request_request.dart';
import '../dto/set_capex_request_executed_date_request.dart';
import 'handler_diff.dart';

/// Shelf request handlers for the /capex-requests REST resource.
class CapexRequestHandler {
  final CreateCapexRequestUseCase _create;
  final GetCapexRequestUseCase _get;
  final ListCapexRequestsUseCase _list;
  final UpdateCapexRequestUseCase _update;
  final DeleteCapexRequestUseCase _delete;
  final DecideCapexRequestUseCase _decide;
  final GetNextCapexRequestNoUseCase _nextNumber;
  final SetCapexRequestExecutedDateUseCase _setExecutedDate;

  const CapexRequestHandler({
    required CreateCapexRequestUseCase create,
    required GetCapexRequestUseCase get,
    required ListCapexRequestsUseCase list,
    required UpdateCapexRequestUseCase update,
    required DeleteCapexRequestUseCase delete,
    required DecideCapexRequestUseCase decide,
    required GetNextCapexRequestNoUseCase nextNumber,
    required SetCapexRequestExecutedDateUseCase setExecutedDate,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _decide = decide,
        _nextNumber = nextNumber,
        _setExecutedDate = setExecutedDate;

  /// GET /capex-requests/next-number — returns the next request number.
  Future<Response> handleNextNumber(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final requestNo = await _nextNumber.execute(entityId);
    return Response.ok(
      jsonEncode({'requestNo': requestNo, 'format': GetNextCapexRequestNoUseCase.format}),
      headers: _jsonHeaders,
    );
  }

  /// GET /capex-requests
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();
    final requests = await _list.execute(entityId: entityId);
    return Response.ok(
      jsonEncode(
          requests.map((r) => CapexRequestResponse.fromEntity(r).toJson()).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /capex-requests
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final CreateCapexRequestRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = CreateCapexRequestRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    try {
      final capexRequest = await _create.execute(
        entityId: entityId,
        requestNo: dto.requestNo,
        requestDate: dto.requestDate,
        preparedByName: dto.preparedByName,
        description: dto.description,
        whatIsRequested: dto.whatIsRequested,
        needOrBenefit: dto.needOrBenefit,
        alternativesConsidered: dto.alternativesConsidered,
        purchaseCostCents: dto.purchaseCostCents,
        ongoingCostsCents: dto.ongoingCostsCents,
        otherCostsCents: dto.otherCostsCents,
        costNotes: dto.costNotes,
        totalAmountCents: dto.totalAmountCents,
        quotesReceivedCount: dto.quotesReceivedCount,
      );
      _auditChanges(request)?.set(_snapshot(capexRequest));
      return Response(
        201,
        body: CapexRequestResponse.fromEntity(capexRequest).toJsonString(),
        headers: _jsonHeaders,
      );
    } on CapexRequestValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /capex-requests/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();
    try {
      final capexRequest = await _get.execute(id, entityId: entityId);
      return Response.ok(
        CapexRequestResponse.fromEntity(capexRequest).toJsonString(),
        headers: _jsonHeaders,
      );
    } on CapexRequestNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /capex-requests/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final CreateCapexRequestRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = CreateCapexRequestRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    CapexRequest? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      final capexRequest = await _update.execute(
        id: id,
        entityId: entityId,
        requestNo: dto.requestNo,
        requestDate: dto.requestDate,
        preparedByName: dto.preparedByName,
        description: dto.description,
        whatIsRequested: dto.whatIsRequested,
        needOrBenefit: dto.needOrBenefit,
        alternativesConsidered: dto.alternativesConsidered,
        purchaseCostCents: dto.purchaseCostCents,
        ongoingCostsCents: dto.ongoingCostsCents,
        otherCostsCents: dto.otherCostsCents,
        costNotes: dto.costNotes,
        totalAmountCents: dto.totalAmountCents,
        quotesReceivedCount: dto.quotesReceivedCount,
      );
      if (before != null) {
        final diff = diffMaps(_snapshot(before), _snapshot(capexRequest));
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      return Response.ok(
        CapexRequestResponse.fromEntity(capexRequest).toJsonString(),
        headers: _jsonHeaders,
      );
    } on CapexRequestNotFoundException catch (e) {
      return _notFound(e.message);
    } on CapexRequestValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// POST /capex-requests/:id/decision
  Future<Response> handleDecide(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final DecideCapexRequestRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = DecideCapexRequestRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    try {
      final capexRequest = await _decide.execute(
        id: id,
        entityId: entityId,
        status: dto.status,
        decisionByName: dto.decisionByName,
        decisionNotes: dto.decisionNotes,
      );
      _auditChanges(request)?.set({
        'requestNo': capexRequest.requestNo,
        'status': capexRequest.status.name,
        'decisionByName': capexRequest.decisionByName,
        'decisionNotes': capexRequest.decisionNotes,
      });
      return Response.ok(
        CapexRequestResponse.fromEntity(capexRequest).toJsonString(),
        headers: _jsonHeaders,
      );
    } on CapexRequestNotFoundException catch (e) {
      return _notFound(e.message);
    } on CapexRequestValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// PUT /capex-requests/:id/executed-date
  Future<Response> handleSetExecutedDate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final SetCapexRequestExecutedDateRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = SetCapexRequestExecutedDateRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    try {
      final capexRequest = await _setExecutedDate.execute(
        id: id,
        entityId: entityId,
        executedDate: dto.executedDate,
      );
      _auditChanges(request)?.set({
        'requestNo': capexRequest.requestNo,
        'executedDate': capexRequest.executedDate?.toIso8601String().substring(0, 10),
      });
      return Response.ok(
        CapexRequestResponse.fromEntity(capexRequest).toJsonString(),
        headers: _jsonHeaders,
      );
    } on CapexRequestNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// DELETE /capex-requests/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    CapexRequest? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) _auditChanges(request)?.set(_snapshot(before));
      return Response(204);
    } on CapexRequestNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String? _entityId(Request request) => resolveEntityId(request);

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Map<String, dynamic> _snapshot(CapexRequest r) => {
        'requestNo': r.requestNo,
        'requestDate': r.requestDate.toIso8601String().substring(0, 10),
        'preparedByName': r.preparedByName,
        'description': r.description,
        'whatIsRequested': r.whatIsRequested,
        'needOrBenefit': r.needOrBenefit,
        'alternativesConsidered': r.alternativesConsidered,
        'purchaseCostCents': r.purchaseCostCents,
        'ongoingCostsCents': r.ongoingCostsCents,
        'otherCostsCents': r.otherCostsCents,
        'costNotes': r.costNotes,
        'totalAmountCents': r.totalAmountCents,
        'quotesReceivedCount': r.quotesReceivedCount,
        'status': r.status.name,
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
