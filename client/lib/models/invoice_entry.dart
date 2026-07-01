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

/// A line item within a full invoice detail response.
class InvoiceLineItemEntry {
  final String id;
  final String description;
  final String generalLedgerId;
  final int amountCents;
  final int gstCents;

  const InvoiceLineItemEntry({
    required this.id,
    required this.description,
    required this.generalLedgerId,
    required this.amountCents,
    required this.gstCents,
  });

  factory InvoiceLineItemEntry.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItemEntry(
      id: json['id'] as String,
      description: json['description'] as String,
      generalLedgerId: json['generalLedgerId'] as String,
      amountCents: json['amountCents'] as int,
      gstCents: json['gstCents'] as int,
    );
  }
}

/// A summary of an invoice returned by GET /invoices.
/// When loaded via GET /invoices/:id, [lineItems] is populated.
class InvoiceEntry {
  final String id;
  final String invoiceNumber;
  final String invoiceDate;
  final String contactId;
  final int totalAmountCents;
  final int totalGstCents;
  final String? paidAt;
  final List<InvoiceLineItemEntry>? lineItems;

  const InvoiceEntry({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.contactId,
    required this.totalAmountCents,
    required this.totalGstCents,
    this.paidAt,
    this.lineItems,
  });

  bool get isPaid => paidAt != null;

  int get totalWithGstCents => totalAmountCents + totalGstCents;

  factory InvoiceEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['lineItems'] as List<dynamic>?;
    return InvoiceEntry(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      invoiceDate: json['invoiceDate'] as String,
      contactId: json['contactId'] as String,
      totalAmountCents: json['totalAmountCents'] as int,
      totalGstCents: json['totalGstCents'] as int,
      paidAt: json['paidAt'] as String?,
      lineItems: rawItems
          ?.map((e) =>
              InvoiceLineItemEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
