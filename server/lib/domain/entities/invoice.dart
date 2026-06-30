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

/// A line item belonging to an [Invoice].
class InvoiceLineItem {
  /// Unique identifier (UUID v4).
  final String id;

  /// FK — the invoice this line item belongs to.
  final String invoiceId;

  /// Free-text description of the item.
  final String description;

  /// FK — the general ledger account this item is coded to.
  final String generalLedgerId;

  /// Amount excluding GST, in cents.
  final int amountCents;

  /// GST component, in cents.
  final int gstCents;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  const InvoiceLineItem({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.generalLedgerId,
    required this.amountCents,
    required this.gstCents,
    required this.createdAt,
  });

  /// Total value of this line item including GST, in cents.
  int get totalCents => amountCents + gstCents;
}

/// A tax invoice raised against a contact.
class Invoice {
  /// Unique identifier (UUID v4).
  final String id;

  /// Multi-tenancy scoping key.
  final String entityId;

  /// Human-readable invoice number (e.g. WMS-26-001).
  final String invoiceNumber;

  /// The date the invoice was raised.
  final DateTime invoiceDate;

  /// FK — the contact this invoice is addressed to.
  final String contactId;

  /// Total amount excluding GST across all line items, in cents.
  final int totalAmountCents;

  /// Total GST across all line items, in cents.
  final int totalGstCents;

  /// Timestamp when the invoice was marked paid; null when unpaid.
  final DateTime? paidAt;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Line items belonging to this invoice.
  final List<InvoiceLineItem> lineItems;

  const Invoice({
    required this.id,
    required this.entityId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.contactId,
    required this.totalAmountCents,
    required this.totalGstCents,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
    this.lineItems = const [],
  });

  bool get isPaid => paidAt != null;

  /// Total value including GST, in cents.
  int get totalWithGstCents => totalAmountCents + totalGstCents;
}
