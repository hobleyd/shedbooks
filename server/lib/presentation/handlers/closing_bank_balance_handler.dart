import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/closing_bank_balance/list_closing_bank_balances_use_case.dart';
import '../../application/closing_bank_balance/save_closing_bank_balance_use_case.dart';
import '../audit_changes.dart';

/// Shelf request handlers for /closing-bank-balances.
class ClosingBankBalanceHandler {
  final SaveClosingBankBalanceUseCase _save;
  final ListClosingBankBalancesUseCase _list;

  const ClosingBankBalanceHandler({
    required SaveClosingBankBalanceUseCase save,
    required ListClosingBankBalancesUseCase list,
  })  : _save = save,
        _list = list;

  /// GET /closing-bank-balances?bankAccountId=<uuid>
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final bankAccountId = request.url.queryParameters['bankAccountId'];
    if (bankAccountId == null || bankAccountId.isEmpty) {
      return _badRequest('bankAccountId query parameter is required');
    }

    final balances = await _list.execute(
      entityId: entityId,
      bankAccountId: bankAccountId,
    );
    return Response.ok(
      jsonEncode(balances.map((b) => b.toJson()).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /closing-bank-balances
  ///
  /// Body: { bankAccountId, balanceDate, balanceCents, statementPeriod }
  Future<Response> handleSave(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final bankAccountId = json['bankAccountId'] as String?;
    final balanceDate = json['balanceDate'] as String?;
    final balanceCents = json['balanceCents'] as int?;
    final statementPeriod = json['statementPeriod'] as String?;

    if (bankAccountId == null || bankAccountId.isEmpty) {
      return _badRequest('bankAccountId is required');
    }
    if (balanceDate == null || balanceDate.isEmpty) {
      return _badRequest('balanceDate is required');
    }
    if (balanceCents == null) {
      return _badRequest('balanceCents is required');
    }
    if (statementPeriod == null || statementPeriod.isEmpty) {
      return _badRequest('statementPeriod is required');
    }

    final balance = await _save.execute(
      entityId: entityId,
      bankAccountId: bankAccountId,
      balanceDate: balanceDate,
      balanceCents: balanceCents,
      statementPeriod: statementPeriod,
    );

    _auditChanges(request)?.set({
      'bankAccountId': balance.bankAccountId,
      'balanceDate': balance.balanceDate,
      'balanceCents': balance.balanceCents,
      'statementPeriod': balance.statementPeriod,
    });

    return Response(201,
        body: jsonEncode(balance.toJson()), headers: _jsonHeaders);
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Response _orgRequired() => Response.unauthorized(
      jsonEncode({'error': 'Organization authentication required'}),
      headers: _jsonHeaders);

  static Response _badRequest(String message) => Response(400,
      body: jsonEncode({'error': message}), headers: _jsonHeaders);

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
