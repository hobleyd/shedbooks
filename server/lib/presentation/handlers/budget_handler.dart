import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/budget/confirm_budget_import_use_case.dart';
import '../../application/budget/delete_budget_use_case.dart';
import '../../application/budget/get_budget_gl_mappings_use_case.dart';
import '../../application/budget/get_budget_use_case.dart';
import '../../application/budget/list_budget_years_use_case.dart';
import '../../application/budget/parse_budget_import_use_case.dart';
import '../../application/budget/save_budget_gl_mappings_use_case.dart';
import '../../application/budget/save_budget_use_case.dart';
import '../../domain/exceptions/budget_exception.dart';
import '../dto/budget_gl_mappings_response.dart';
import '../dto/budget_response.dart';
import '../dto/confirm_import_request.dart';
import '../dto/parse_import_response.dart';
import '../dto/save_budget_gl_mappings_request.dart';
import '../dto/save_budget_request.dart';

/// Shelf request handlers for the /budgets resource.
class BudgetHandler {
  final ListBudgetYearsUseCase _listYears;
  final GetBudgetUseCase _get;
  final SaveBudgetUseCase _save;
  final DeleteBudgetUseCase _delete;
  final ParseBudgetImportUseCase _parseImport;
  final ConfirmBudgetImportUseCase _confirmImport;
  final GetBudgetGlMappingsUseCase _getMappings;
  final SaveBudgetGlMappingsUseCase _saveMappings;

  const BudgetHandler({
    required ListBudgetYearsUseCase listYears,
    required GetBudgetUseCase get,
    required SaveBudgetUseCase save,
    required DeleteBudgetUseCase delete,
    required ParseBudgetImportUseCase parseImport,
    required ConfirmBudgetImportUseCase confirmImport,
    required GetBudgetGlMappingsUseCase getMappings,
    required SaveBudgetGlMappingsUseCase saveMappings,
  })  : _listYears = listYears,
        _get = get,
        _save = save,
        _delete = delete,
        _parseImport = parseImport,
        _confirmImport = confirmImport,
        _getMappings = getMappings,
        _saveMappings = saveMappings;

  /// GET /budgets — returns list of years that have a saved budget.
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final years = await _listYears.execute(entityId: entityId);
    return Response.ok(jsonEncode(years), headers: _jsonHeaders);
  }

  /// GET /budgets/<year>
  Future<Response> handleGet(Request request, String yearStr) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final year = int.tryParse(yearStr);
    if (year == null) return _badRequest('year must be an integer');

    final lines = await _get.execute(year, entityId: entityId);
    final response = BudgetResponse.fromLines(year, lines);
    return Response.ok(response.toJsonString(), headers: _jsonHeaders);
  }

  /// PUT /budgets/<year>
  Future<Response> handleSave(Request request, String yearStr) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final year = int.tryParse(yearStr);
    if (year == null) return _badRequest('year must be an integer');

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final SaveBudgetRequest dto;
    try {
      dto = SaveBudgetRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _save.execute(year, dto.lines, entityId: entityId);
    } on BudgetValidationException catch (e) {
      return _badRequest(e.message);
    }

    final lines = await _get.execute(year, entityId: entityId);
    return Response.ok(
      BudgetResponse.fromLines(year, lines).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// DELETE /budgets/<year>
  Future<Response> handleDelete(Request request, String yearStr) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final year = int.tryParse(yearStr);
    if (year == null) return _badRequest('year must be an integer');

    await _delete.execute(year, entityId: entityId);
    return Response(204);
  }

  /// POST /budgets/parse-import — parses CSV body, returns rows with GL suggestions.
  Future<Response> handleParseImport(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final csvContent = await request.readAsString();
    if (csvContent.trim().isEmpty) {
      return _badRequest('Request body must contain CSV data');
    }

    final rows = await _parseImport.execute(
      csvContent: csvContent,
      entityId: entityId,
    );

    return Response.ok(
      ParseImportResponse(rows: rows).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// POST /budgets/<year>/confirm-import — saves confirmed import rows as budget lines.
  Future<Response> handleConfirmImport(Request request, String yearStr) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final year = int.tryParse(yearStr);
    if (year == null) return _badRequest('year must be an integer');

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final ConfirmImportRequest dto;
    try {
      dto = ConfirmImportRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    await _confirmImport.execute(
      year: year,
      rows: dto.rows,
      saveMappings: dto.saveMappings,
      entityId: entityId,
    );

    final lines = await _get.execute(year, entityId: entityId);
    return Response.ok(
      BudgetResponse.fromLines(year, lines).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// GET /budgets/gl-mappings
  Future<Response> handleGetMappings(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final mappings = await _getMappings.execute(entityId: entityId);
    return Response.ok(
      BudgetGlMappingsResponse(mappings: mappings).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// PUT /budgets/gl-mappings
  Future<Response> handleSaveMappings(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final SaveBudgetGlMappingsRequest dto;
    try {
      dto = SaveBudgetGlMappingsRequest.fromJson(json, entityId);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    await _saveMappings.execute(dto.mappings, entityId: entityId);
    final mappings = await _getMappings.execute(entityId: entityId);
    return Response.ok(
      BudgetGlMappingsResponse(mappings: mappings).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
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
}
