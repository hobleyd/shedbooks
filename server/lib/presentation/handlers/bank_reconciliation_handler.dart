import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import '../../application/bank_account/list_bank_accounts_use_case.dart';
import '../../infrastructure/pdf/cba_statement_parser.dart';

/// Shelf request handlers for /bank-reconciliation.
class BankReconciliationHandler {
  final ListBankAccountsUseCase _listBankAccounts;

  const BankReconciliationHandler({
    required ListBankAccountsUseCase listBankAccounts,
  }) : _listBankAccounts = listBankAccounts;

  /// GET /bank-reconciliation/bank-accounts
  ///
  /// Returns a minimal [{id, accountName}] list for the bank account
  /// dropdown in the reconciliation screen. Contributors can access this
  /// endpoint even though they are blocked from the full /bank-accounts API.
  Future<Response> handleListBankAccounts(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final accounts = await _listBankAccounts.execute(entityId: entityId);
    final payload = accounts
        .map((a) => {'id': a.id, 'accountName': a.accountName})
        .toList();
    return Response.ok(jsonEncode(payload), headers: _jsonHeaders);
  }

  /// POST /bank-reconciliation/parse-statement
  ///
  /// Accepts raw PDF bytes. Returns parsed CBA statement data as JSON.
  Future<Response> handleParseStatement(Request request) async {
    final Uint8List pdfBytes;
    try {
      pdfBytes = Uint8List.fromList(
          await request.read().expand((c) => c).toList());
    } catch (_) {
      return _badRequest('Failed to read request body');
    }

    if (pdfBytes.isEmpty) return _badRequest('PDF bytes required');

    final data = CbaStatementParser.parse(pdfBytes);
    if (data == null) {
      return Response(
        422,
        body: jsonEncode(
            {'error': 'Unable to parse statement — unsupported format'}),
        headers: _jsonHeaders,
      );
    }

    return Response.ok(jsonEncode(data.toJson()), headers: _jsonHeaders);
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

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
