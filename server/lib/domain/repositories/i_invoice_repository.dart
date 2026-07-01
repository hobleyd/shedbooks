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

import '../entities/invoice.dart';

/// A line item payload for creating an invoice.
class InvoiceLineItemInput {
  final String description;
  final String generalLedgerId;
  final int amountCents;
  final int gstCents;

  const InvoiceLineItemInput({
    required this.description,
    required this.generalLedgerId,
    required this.amountCents,
    required this.gstCents,
  });
}

/// Contract for invoice persistence.
abstract interface class IInvoiceRepository {
  /// Creates a new invoice with [lineItems] and returns the persisted entity
  /// including its line items.
  Future<Invoice> create({
    required String entityId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String contactId,
    required List<InvoiceLineItemInput> lineItems,
    String? bankAccountId,
  });

  /// Returns all invoices for [entityId] ordered by invoice_date descending.
  /// When [unpaidOnly] is true, returns only invoices where paid_at IS NULL.
  /// Line items are not populated on list results.
  Future<List<Invoice>> findAll({
    required String entityId,
    bool unpaidOnly = false,
  });

  /// Returns an invoice by [id] within [entityId], including its line items.
  /// Returns null if not found.
  Future<Invoice?> findById(String id, {required String entityId});

  /// Sets [paid_at] on invoice [id] within [entityId].
  /// Returns the updated invoice (without line items).
  Future<Invoice> markPaid(
    String id, {
    required String entityId,
    required DateTime paidAt,
  });

  /// Returns distinct invoice numbers matching [pattern] (SQL LIKE syntax)
  /// for [entityId].
  Future<List<String>> findInvoiceNumbersLike(String pattern,
      {required String entityId});

  /// Updates an unpaid invoice's number, date, line items, and bank account atomically.
  /// Throws [Exception] if the invoice is not found or is already paid.
  Future<Invoice> update({
    required String id,
    required String entityId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<InvoiceLineItemInput> lineItems,
    String? bankAccountId,
  });

  /// Permanently deletes an unpaid invoice and its line items.
  /// Throws [Exception] if the invoice is not found or is already paid.
  Future<void> delete(String id, {required String entityId});
}
