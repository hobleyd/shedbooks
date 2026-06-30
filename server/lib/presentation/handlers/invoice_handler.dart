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

/// Shelf request handlers for /invoices.
class InvoiceHandler {
  final GetNextInvoiceNumberUseCase _nextNumber;

  const InvoiceHandler({required GetNextInvoiceNumberUseCase nextNumber})
      : _nextNumber = nextNumber;

  /// GET /invoices/next-number — returns the next invoice number based on
  /// the entity's configured format, scanning existing transactions to find
  /// the current maximum sequential value.
  Future<Response> handleNextNumber(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );
    }

    final result = await _nextNumber.execute(entityId);
    return Response.ok(
      jsonEncode({
        'invoiceNumber': result.invoiceNumber,
        'format': result.format,
      }),
      headers: _jsonHeaders,
    );
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
