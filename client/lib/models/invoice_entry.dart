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

/// A summary of an invoice returned by GET /invoices.
class InvoiceEntry {
  final String id;
  final String invoiceNumber;
  final String invoiceDate;
  final String contactId;
  final int totalAmountCents;
  final int totalGstCents;
  final String? paidAt;

  const InvoiceEntry({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.contactId,
    required this.totalAmountCents,
    required this.totalGstCents,
    this.paidAt,
  });

  bool get isPaid => paidAt != null;

  int get totalWithGstCents => totalAmountCents + totalGstCents;

  factory InvoiceEntry.fromJson(Map<String, dynamic> json) {
    return InvoiceEntry(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      invoiceDate: json['invoiceDate'] as String,
      contactId: json['contactId'] as String,
      totalAmountCents: json['totalAmountCents'] as int,
      totalGstCents: json['totalGstCents'] as int,
      paidAt: json['paidAt'] as String?,
    );
  }
}
