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

import '../../application/contact/get_contact_use_case.dart';
import '../../application/general_ledger/get_general_ledger_use_case.dart';
import '../../application/transaction/bank_match_transactions_use_case.dart';
import '../../application/transaction/create_transaction_use_case.dart';
import '../../application/transaction/delete_transaction_use_case.dart';
import '../../application/transaction/get_transaction_use_case.dart';
import '../../application/transaction/list_transactions_use_case.dart';
import '../../application/transaction/stamp_aba_batch_use_case.dart';
import '../../application/transaction/update_transaction_use_case.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../audit_changes.dart';
import '../dto/bank_match_request.dart';
import '../dto/create_transaction_request.dart';
import '../dto/stamp_aba_batch_request.dart';
import '../dto/transaction_response.dart';
import '../dto/update_transaction_request.dart';
import 'handler_diff.dart';

/// Shelf request handlers for the /transactions resource.
class TransactionHandler {
  final CreateTransactionUseCase _create;
  final GetTransactionUseCase _get;
  final ListTransactionsUseCase _list;
  final UpdateTransactionUseCase _update;
  final DeleteTransactionUseCase _delete;
  final BankMatchTransactionsUseCase _bankMatch;
  final StampAbaBatchUseCase _stampAbaBatch;
  final GetContactUseCase _getContact;
  final GetGeneralLedgerUseCase _getGeneralLedger;

  const TransactionHandler({
    required CreateTransactionUseCase create,
    required GetTransactionUseCase get,
    required ListTransactionsUseCase list,
    required UpdateTransactionUseCase update,
    required DeleteTransactionUseCase delete,
    required BankMatchTransactionsUseCase bankMatch,
    required StampAbaBatchUseCase stampAbaBatch,
    required GetContactUseCase getContact,
    required GetGeneralLedgerUseCase getGeneralLedger,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _bankMatch = bankMatch,
        _stampAbaBatch = stampAbaBatch,
        _getContact = getContact,
        _getGeneralLedger = getGeneralLedger;

  /// GET /transactions
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final transactions = await _list.execute(entityId: entityId);
    final body = jsonEncode(
      transactions.map((t) => TransactionResponse.fromEntity(t).toJson()).toList(),
    );
    return Response.ok(body, headers: _jsonHeaders);
  }

  /// POST /transactions
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final CreateTransactionRequest dto;
    try {
      dto = CreateTransactionRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final transaction = await _create.execute(
        entityId: entityId,
        contactId: dto.contactId,
        generalLedgerId: dto.generalLedgerId,
        amount: dto.amount,
        gstAmount: dto.gstAmount,
        transactionType: dto.transactionType,
        receiptNumber: dto.receiptNumber,
        paymentReference: dto.paymentReference,
        description: dto.description,
        transactionDate: dto.transactionDate,
        isCash: dto.isCash,
        bankAccountId: dto.bankAccountId,
      );
      final contactLabel = await _contactLabel(transaction.contactId, entityId);
      final glLabel = await _glLabel(transaction.generalLedgerId, entityId);
      _auditChanges(request)?.set(_txSnapshot(transaction, contactLabel, glLabel));
      return Response(
        201,
        body: TransactionResponse.fromEntity(transaction).toJsonString(),
        headers: _jsonHeaders,
      );
    } on MonthIsLockedException catch (e) {
      return _locked(e.message);
    } on TransactionValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /transactions/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    try {
      final transaction = await _get.execute(id, entityId: entityId);
      return Response.ok(
        TransactionResponse.fromEntity(transaction).toJsonString(),
        headers: _jsonHeaders,
      );
    } on TransactionNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /transactions/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final UpdateTransactionRequest dto;
    try {
      dto = UpdateTransactionRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    Transaction? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      final transaction = await _update.execute(
        id: id,
        entityId: entityId,
        contactId: dto.contactId,
        generalLedgerId: dto.generalLedgerId,
        amount: dto.amount,
        gstAmount: dto.gstAmount,
        transactionType: dto.transactionType,
        receiptNumber: dto.receiptNumber,
        paymentReference: dto.paymentReference,
        description: dto.description,
        transactionDate: dto.transactionDate,
        isCash: dto.isCash,
        bankAccountId: dto.bankAccountId,
      );
      if (before != null) {
        final beforeContactLabel = await _contactLabel(before.contactId, entityId);
        final afterContactLabel = await _contactLabel(transaction.contactId, entityId);
        final beforeGlLabel = await _glLabel(before.generalLedgerId, entityId);
        final afterGlLabel = await _glLabel(transaction.generalLedgerId, entityId);
        final diff = diffMaps(
          _txSnapshot(before, beforeContactLabel, beforeGlLabel),
          _txSnapshot(transaction, afterContactLabel, afterGlLabel),
        );
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      return Response.ok(
        TransactionResponse.fromEntity(transaction).toJsonString(),
        headers: _jsonHeaders,
      );
    } on MonthIsLockedException catch (e) {
      return _locked(e.message);
    } on TransactionNotFoundException catch (e) {
      return _notFound(e.message);
    } on TransactionValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// DELETE /transactions/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    Transaction? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) {
        final contactLabel = await _contactLabel(before.contactId, entityId);
        final glLabel = await _glLabel(before.generalLedgerId, entityId);
        _auditChanges(request)?.set(_txSnapshot(before, contactLabel, glLabel));
      }
      return Response(204);
    } on MonthIsLockedException catch (e) {
      return _locked(e.message);
    } on TransactionNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// POST /transactions/bank-match
  Future<Response> handleBankMatch(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final BankMatchRequest dto;
    try {
      dto = BankMatchRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _bankMatch.execute(
        ids: dto.transactionIds,
        entityId: entityId,
        bankAccountId: dto.bankAccountId,
        transactionDate: dto.transactionDate,
      );
    } on MonthIsLockedException catch (e) {
      return _locked(e.message);
    } catch (e) {
      return _serverError('Failed to save bank matches: $e');
    }

    final matched = <Map<String, dynamic>>[];
    for (final id in dto.transactionIds) {
      try {
        final tx = await _get.execute(id, entityId: entityId);
        matched.add({
          'receiptNumber': tx.receiptNumber,
          'description': tx.description,
          'date': tx.transactionDate.toIso8601String().substring(0, 10),
          'amountCents': tx.totalAmount,
        });
      } catch (_) {}
    }
    if (matched.isNotEmpty) {
      _auditChanges(request)?.set({'matched': matched});
    }

    return Response(204);
  }

  /// POST /transactions/aba-batch
  Future<Response> handleStampAbaBatch(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final StampAbaBatchRequest dto;
    try {
      dto = StampAbaBatchRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _stampAbaBatch.execute(
        ids: dto.transactionIds,
        batchName: dto.batchName,
        entityId: entityId,
      );
    } catch (e) {
      return _serverError('Failed to stamp ABA batch: $e');
    }

    _auditChanges(request)?.set({
      'abaBatch': dto.batchName,
      'transactionCount': dto.transactionIds.length,
    });

    return Response(204);
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  Future<String> _contactLabel(String contactId, String entityId) async {
    try {
      final contact = await _getContact.execute(contactId, entityId: entityId);
      return '${contact.name} ($contactId)';
    } catch (_) {
      return contactId;
    }
  }

  Future<String> _glLabel(String generalLedgerId, String entityId) async {
    try {
      final gl = await _getGeneralLedger.execute(generalLedgerId, entityId: entityId);
      return '${gl.label} ($generalLedgerId)';
    } catch (_) {
      return generalLedgerId;
    }
  }

  static Map<String, dynamic> _txSnapshot(
    Transaction t,
    String contactLabel,
    String glLabel,
  ) => {
        'contact': contactLabel,
        'generalLedger': glLabel,
        'amount': t.amount,
        'gstAmount': t.gstAmount,
        'transactionType': t.transactionType.name,
        'receiptNumber': t.receiptNumber,
        'paymentReference': t.paymentReference,
        'description': t.description,
        'transactionDate': t.transactionDate.toIso8601String(),
      };

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

  static Response _locked(String message) => Response(
        422,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _serverError(String message) => Response(
        500,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );
}
