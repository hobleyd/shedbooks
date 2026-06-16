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

import '../../application/bank_account/create_bank_account_use_case.dart';
import '../../application/bank_account/delete_bank_account_use_case.dart';
import '../../application/bank_account/get_bank_account_use_case.dart';
import '../../application/bank_account/list_bank_accounts_use_case.dart';
import '../../application/bank_account/reorder_bank_accounts_use_case.dart';
import '../../application/bank_account/update_bank_account_use_case.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/exceptions/bank_account_exception.dart';
import '../audit_changes.dart';
import '../dto/bank_account_response.dart';
import '../dto/create_bank_account_request.dart';
import '../dto/update_bank_account_request.dart';
import 'handler_diff.dart';

/// Shelf request handlers for /bank-accounts.
class BankAccountHandler {
  final CreateBankAccountUseCase _create;
  final GetBankAccountUseCase _get;
  final ListBankAccountsUseCase _list;
  final UpdateBankAccountUseCase _update;
  final DeleteBankAccountUseCase _delete;
  final ReorderBankAccountsUseCase _reorder;

  const BankAccountHandler({
    required CreateBankAccountUseCase create,
    required GetBankAccountUseCase get,
    required ListBankAccountsUseCase list,
    required UpdateBankAccountUseCase update,
    required DeleteBankAccountUseCase delete,
    required ReorderBankAccountsUseCase reorder,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _reorder = reorder;

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
      _auditChanges(request)?.set(_accountSnapshot(account, redact: true));
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

    BankAccount? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    if (before?.isSystem == true) {
      return _badRequest('System accounts cannot be modified.');
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
      if (before != null) {
        final bSnap = _accountSnapshot(before, redact: true);
        final aSnap = _accountSnapshot(account, redact: true);
        final diff = diffMaps(bSnap, aSnap);
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      return Response.ok(
          BankAccountResponse.fromEntity(account).toJsonString(),
          headers: _jsonHeaders);
    } on BankAccountNotFoundException catch (e) {
      return _notFound(e.message);
    } on BankAccountValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// PUT /bank-accounts/order — body: {"ids": ["uuid", ...]}
  Future<Response> handleReorder(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final rawIds = json['ids'];
    if (rawIds is! List) return _badRequest('ids must be an array');
    final ids = rawIds.whereType<String>().toList();

    await _reorder.execute(entityId: entityId, ids: ids);
    return Response(204);
  }

  /// DELETE /bank-accounts/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    BankAccount? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    if (before?.isSystem == true) {
      return _badRequest('System accounts cannot be deleted.');
    }

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) {
        _auditChanges(request)?.set(_accountSnapshot(before, redact: true));
      }
      return Response(204);
    } on BankAccountNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Map<String, dynamic> _accountSnapshot(BankAccount a,
          {bool redact = false}) =>
      {
        'bankName': a.bankName,
        'accountName': a.accountName,
        'bsb': redact ? '***' : a.bsb,
        'accountNumber': redact ? '***' : a.accountNumber,
        'accountType': a.accountType.name,
        'currency': a.currency,
      };

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
