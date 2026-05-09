import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/bank_account/create_bank_account_use_case.dart';
import '../../application/bank_account/delete_bank_account_use_case.dart';
import '../../application/bank_account/get_bank_account_use_case.dart';
import '../../application/bank_account/list_bank_accounts_use_case.dart';
import '../../application/bank_account/update_bank_account_use_case.dart';
import '../../domain/exceptions/bank_account_exception.dart';
import '../dto/bank_account_response.dart';
import '../dto/create_bank_account_request.dart';
import '../dto/update_bank_account_request.dart';

/// Shelf request handlers for /bank-accounts.
class BankAccountHandler {
  final CreateBankAccountUseCase _create;
  final GetBankAccountUseCase _get;
  final ListBankAccountsUseCase _list;
  final UpdateBankAccountUseCase _update;
  final DeleteBankAccountUseCase _delete;

  const BankAccountHandler({
    required CreateBankAccountUseCase create,
    required GetBankAccountUseCase get,
    required ListBankAccountsUseCase list,
    required UpdateBankAccountUseCase update,
    required DeleteBankAccountUseCase delete,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete;

  /// GET /bank-accounts
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final accounts = await _list.execute(entityId: entityId);
    return Response.ok(
      jsonEncode(accounts.map((a) => BankAccountResponse.fromEntity(a).toJson()).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /bank-accounts
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final CreateBankAccountRequest dto;
    try {
      dto = CreateBankAccountRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final account = await _create.execute(
        entityId: entityId,
        bankName: dto.bankName,
        accountName: dto.accountName,
        bsb: dto.bsb,
        accountNumber: dto.accountNumber,
        accountType: dto.accountType,
        currency: dto.currency,
      );
      return Response(201,
          body: BankAccountResponse.fromEntity(account).toJsonString(),
          headers: _jsonHeaders);
    } on BankAccountValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /bank-accounts/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    try {
      final account = await _get.execute(id, entityId: entityId);
      return Response.ok(
          BankAccountResponse.fromEntity(account).toJsonString(),
          headers: _jsonHeaders);
    } on BankAccountNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /bank-accounts/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final UpdateBankAccountRequest dto;
    try {
      dto = UpdateBankAccountRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final account = await _update.execute(
        id: id,
        entityId: entityId,
        bankName: dto.bankName,
        accountName: dto.accountName,
        bsb: dto.bsb,
        accountNumber: dto.accountNumber,
        accountType: dto.accountType,
        currency: dto.currency,
      );
      return Response.ok(
          BankAccountResponse.fromEntity(account).toJsonString(),
          headers: _jsonHeaders);
    } on BankAccountNotFoundException catch (e) {
      return _notFound(e.message);
    } on BankAccountValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// DELETE /bank-accounts/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    try {
      await _delete.execute(id, entityId: entityId);
      return Response(204);
    } on BankAccountNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static Response _orgRequired() => Response.unauthorized(
      jsonEncode({'error': 'Organization authentication required'}),
      headers: _jsonHeaders);

  static Response _badRequest(String message) => Response(400,
      body: jsonEncode({'error': message}), headers: _jsonHeaders);

  static Response _notFound(String message) =>
      Response.notFound(jsonEncode({'error': message}), headers: _jsonHeaders);

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
