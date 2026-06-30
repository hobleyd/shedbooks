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

import '../../application/entity/get_next_invoice_number_use_case.dart';
import '../../application/invoice/create_invoice_use_case.dart';
import '../../application/invoice/list_invoices_use_case.dart';
import '../../application/invoice/mark_invoice_paid_use_case.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/i_invoice_repository.dart';
import '../audit_changes.dart';

/// Shelf request handlers for /invoices.
class InvoiceHandler {
  final GetNextInvoiceNumberUseCase _nextNumber;
  final CreateInvoiceUseCase _create;
  final ListInvoicesUseCase _list;
  final MarkInvoicePaidUseCase _markPaid;

  const InvoiceHandler({
    required GetNextInvoiceNumberUseCase nextNumber,
    required CreateInvoiceUseCase create,
    required ListInvoicesUseCase list,
    required MarkInvoicePaidUseCase markPaid,
  })  : _nextNumber = nextNumber,
        _create = create,
        _list = list,
        _markPaid = markPaid;

  /// GET /invoices/next-number — returns the next invoice number.
  Future<Response> handleNextNumber(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final result = await _nextNumber.execute(entityId);
    return Response.ok(
      jsonEncode({
        'invoiceNumber': result.invoiceNumber,
        'format': result.format,
      }),
      headers: _jsonHeaders,
    );
  }

  /// GET /invoices — lists all invoices. Pass ?unpaid=true to filter unpaid.
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final unpaidOnly =
        request.url.queryParameters['unpaid'] == 'true';

    final invoices = await _list.execute(entityId, unpaidOnly: unpaidOnly);
    return Response.ok(
      jsonEncode(invoices.map(_toJson).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /invoices — creates a new invoice.
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return Response(HttpStatus.badRequest,
          body: jsonEncode({'error': 'Invalid JSON'}), headers: _jsonHeaders);
    }

    final invoiceNumber = body['invoiceNumber'] as String?;
    final invoiceDateStr = body['invoiceDate'] as String?;
    final contactId = body['contactId'] as String?;
    final lineItemsRaw = body['lineItems'] as List<dynamic>?;

    if (invoiceNumber == null || invoiceNumber.isEmpty) {
      return _badRequest('invoiceNumber is required');
    }
    if (invoiceDateStr == null) return _badRequest('invoiceDate is required');
    if (contactId == null) return _badRequest('contactId is required');
    if (lineItemsRaw == null || lineItemsRaw.isEmpty) {
      return _badRequest('lineItems must not be empty');
    }

    final DateTime invoiceDate;
    try {
      invoiceDate = DateTime.parse(invoiceDateStr);
    } catch (_) {
      return _badRequest('Invalid invoiceDate format');
    }

    final lineItems = <InvoiceLineItemInput>[];
    for (final raw in lineItemsRaw) {
      final item = raw as Map<String, dynamic>;
      final glId = item['generalLedgerId'] as String?;
      final amount = item['amountCents'] as int?;
      if (glId == null) return _badRequest('Each lineItem must have generalLedgerId');
      if (amount == null) return _badRequest('Each lineItem must have amountCents');
      lineItems.add(InvoiceLineItemInput(
        description: (item['description'] as String?) ?? '',
        generalLedgerId: glId,
        amountCents: amount,
        gstCents: (item['gstCents'] as int?) ?? 0,
      ));
    }

    try {
      final invoice = await _create.execute(
        entityId: entityId,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        contactId: contactId,
        lineItems: lineItems,
      );

      _auditChanges(request)?.set({
        'invoiceNumber': invoiceNumber,
        'contactId': contactId,
        'totalCents': invoice.totalAmountCents + invoice.totalGstCents,
        'lineCount': invoice.lineItems.length,
      });

      return Response(HttpStatus.created,
          body: jsonEncode(_toJsonWithLineItems(invoice)),
          headers: _jsonHeaders);
    } catch (e) {
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        return Response(HttpStatus.conflict,
            body: jsonEncode({'error': 'Invoice number already exists'}),
            headers: _jsonHeaders);
      }
      rethrow;
    }
  }

  /// POST /invoices/:id/mark-paid — creates transactions and marks invoice paid.
  Future<Response> handleMarkPaid(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return Response(HttpStatus.badRequest,
          body: jsonEncode({'error': 'Invalid JSON'}), headers: _jsonHeaders);
    }

    final transactionDateStr = body['transactionDate'] as String?;
    if (transactionDateStr == null) {
      return _badRequest('transactionDate is required');
    }

    final DateTime transactionDate;
    try {
      transactionDate = DateTime.parse(transactionDateStr);
    } catch (_) {
      return _badRequest('Invalid transactionDate format');
    }

    try {
      final invoice = await _markPaid.execute(id,
          entityId: entityId, transactionDate: transactionDate);

      _auditChanges(request)?.set({
        'invoiceNumber': invoice.invoiceNumber,
        'paidAt': invoice.paidAt?.toIso8601String(),
        'transactionDate': transactionDateStr,
      });

      return Response.ok(
          jsonEncode(_toJson(invoice)), headers: _jsonHeaders);
    } catch (e) {
      if (e.toString().contains('not found')) {
        return Response.notFound(
            jsonEncode({'error': e.toString()}), headers: _jsonHeaders);
      }
      if (e.toString().contains('already paid')) {
        return Response(HttpStatus.conflict,
            body: jsonEncode({'error': e.toString()}),
            headers: _jsonHeaders);
      }
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static AuditChanges? _auditChanges(Request r) =>
      r.context['audit.changes'] as AuditChanges?;

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static Response _unauthorized() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _badRequest(String msg) => Response(
        HttpStatus.badRequest,
        body: jsonEncode({'error': msg}),
        headers: _jsonHeaders,
      );

  static Map<String, dynamic> _toJson(Invoice invoice) => {
        'id': invoice.id,
        'invoiceNumber': invoice.invoiceNumber,
        'invoiceDate':
            invoice.invoiceDate.toIso8601String().substring(0, 10),
        'contactId': invoice.contactId,
        'totalAmountCents': invoice.totalAmountCents,
        'totalGstCents': invoice.totalGstCents,
        'paidAt': invoice.paidAt?.toIso8601String(),
        'createdAt': invoice.createdAt.toIso8601String(),
        'updatedAt': invoice.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _toJsonWithLineItems(Invoice invoice) => {
        ..._toJson(invoice),
        'lineItems': invoice.lineItems
            .map((item) => {
                  'id': item.id,
                  'description': item.description,
                  'generalLedgerId': item.generalLedgerId,
                  'amountCents': item.amountCents,
                  'gstCents': item.gstCents,
                })
            .toList(),
      };

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
