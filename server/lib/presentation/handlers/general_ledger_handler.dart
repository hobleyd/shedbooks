import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../../application/general_ledger/create_general_ledger_use_case.dart';
import '../../application/general_ledger/delete_general_ledger_use_case.dart';
import '../../application/general_ledger/get_general_ledger_use_case.dart';
import '../../application/general_ledger/list_general_ledgers_use_case.dart';
import '../../application/general_ledger/update_general_ledger_use_case.dart';
import '../../domain/exceptions/general_ledger_exception.dart';
import '../dto/create_general_ledger_request.dart';
import '../dto/general_ledger_response.dart';
import '../dto/update_general_ledger_request.dart';

/// Shelf request handlers for the /general-ledger resource.
class GeneralLedgerHandler {
  final CreateGeneralLedgerUseCase _create;
  final GetGeneralLedgerUseCase _get;
  final ListGeneralLedgersUseCase _list;
  final UpdateGeneralLedgerUseCase _update;
  final DeleteGeneralLedgerUseCase _delete;

  const GeneralLedgerHandler({
    required CreateGeneralLedgerUseCase create,
    required GetGeneralLedgerUseCase get,
    required ListGeneralLedgersUseCase list,
    required UpdateGeneralLedgerUseCase update,
    required DeleteGeneralLedgerUseCase delete,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete;

  /// GET /general-ledger
  Future<Response> handleList(Request request) async {
    final accounts = await _list.execute();
    final body = jsonEncode(
      accounts.map((a) => GeneralLedgerResponse.fromEntity(a).toJson()).toList(),
    );
    return Response.ok(body, headers: _jsonHeaders);
  }

  /// POST /general-ledger
  Future<Response> handleCreate(Request request) async {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final CreateGeneralLedgerRequest dto;
    try {
      dto = CreateGeneralLedgerRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final account = await _create.execute(
        label: dto.label,
        description: dto.description,
        gstApplicable: dto.gstApplicable,
      );
      return Response(
        201,
        body: GeneralLedgerResponse.fromEntity(account).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GeneralLedgerValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /general-ledger/:id
  Future<Response> handleGet(Request request, String id) async {
    try {
      final account = await _get.execute(id);
      return Response.ok(
        GeneralLedgerResponse.fromEntity(account).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GeneralLedgerNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /general-ledger/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final UpdateGeneralLedgerRequest dto;
    try {
      dto = UpdateGeneralLedgerRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final account = await _update.execute(
        id: id,
        label: dto.label,
        description: dto.description,
        gstApplicable: dto.gstApplicable,
      );
      return Response.ok(
        GeneralLedgerResponse.fromEntity(account).toJsonString(),
        headers: _jsonHeaders,
      );
    } on GeneralLedgerNotFoundException catch (e) {
      return _notFound(e.message);
    } on GeneralLedgerValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// DELETE /general-ledger/:id
  Future<Response> handleDelete(Request request, String id) async {
    try {
      await _delete.execute(id);
      return Response(204);
    } on GeneralLedgerNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  static const Map<String, String> _jsonHeaders = {
    'content-type': 'application/json',
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
