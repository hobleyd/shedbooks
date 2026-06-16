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

import '../../application/bank_import/get_bank_imports_use_case.dart';
import '../../application/bank_import/save_bank_imports_use_case.dart';
import '../audit_changes.dart';
import '../dto/bank_import_response.dart';
import '../dto/save_bank_imports_request.dart';

/// Shelf request handlers for /bank-imports.
class BankImportsHandler {
  final GetBankImportsUseCase _get;
  final SaveBankImportsUseCase _save;

  const BankImportsHandler({
    required GetBankImportsUseCase get,
    required SaveBankImportsUseCase save,
  })  : _get = get,
        _save = save;

  /// GET /bank-imports — returns all previously-imported rows for this entity.
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final rows = await _get.execute(entityId);
    return Response.ok(
      BankImportResponse.toJsonList(
          rows.map(BankImportResponse.fromEntity).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /bank-imports — records actioned rows from an import session.
  Future<Response> handleSave(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final SaveBankImportsRequest dto;
    try {
      dto = SaveBankImportsRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    await _save.execute(entityId: entityId, rows: dto.rows);
    _auditChanges(request)?.set({
      'rows': dto.rows
          .map((r) => {
                'processDate': r.processDate,
                'description': r.description,
                'amountCents': r.amountCents,
                'isDebit': r.isDebit,
              })
          .toList(),
    });
    return Response(HttpStatus.noContent);
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

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
