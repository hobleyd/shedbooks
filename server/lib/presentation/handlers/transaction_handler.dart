import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';

import '../../application/contact/get_contact_use_case.dart';
import '../../application/transaction/bank_match_transactions_use_case.dart';
import '../../application/transaction/create_transaction_use_case.dart';
import '../../application/transaction/delete_transaction_use_case.dart';
import '../../application/transaction/get_transaction_use_case.dart';
import '../../application/transaction/list_transactions_use_case.dart';
import '../../application/transaction/update_transaction_use_case.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../audit_changes.dart';
import '../dto/bank_match_request.dart';
import '../dto/create_transaction_request.dart';
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
  final GetContactUseCase _getContact;

  const TransactionHandler({
    required CreateTransactionUseCase create,
    required GetTransactionUseCase get,
    required ListTransactionsUseCase list,
    required UpdateTransactionUseCase update,
    required DeleteTransactionUseCase delete,
    required BankMatchTransactionsUseCase bankMatch,
    required GetContactUseCase getContact,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _bankMatch = bankMatch,
        _getContact = getContact;

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
        description: dto.description,
        transactionDate: dto.transactionDate,
      );
      final contactLabel = await _contactLabel(transaction.contactId, entityId);
      _auditChanges(request)?.set(_txSnapshot(transaction, contactLabel));
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
        description: dto.description,
        transactionDate: dto.transactionDate,
      );
      if (before != null) {
        final beforeLabel = await _contactLabel(before.contactId, entityId);
        final afterLabel = await _contactLabel(transaction.contactId, entityId);
        final diff = diffMaps(
          _txSnapshot(before, beforeLabel),
          _txSnapshot(transaction, afterLabel),
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
        _auditChanges(request)?.set(_txSnapshot(before, contactLabel));
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
      await _bankMatch.execute(ids: dto.transactionIds, entityId: entityId);
    } catch (e) {
      return _serverError('Failed to save bank matches: $e');
    }
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

  static Map<String, dynamic> _txSnapshot(Transaction t, String contactLabel) => {
        'contact': contactLabel,
        'generalLedgerId': t.generalLedgerId,
        'amount': t.amount,
        'gstAmount': t.gstAmount,
        'transactionType': t.transactionType.name,
        'receiptNumber': t.receiptNumber,
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
