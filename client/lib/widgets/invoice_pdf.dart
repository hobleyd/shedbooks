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

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bank_account_summary.dart';
import '../models/entity_details.dart';
import '../models/invoice_line_item.dart';
import '../utils/formatters.dart';
import 'pdf_report_components.dart';

class InvoicePdf {
  static Future<void> generateAndDownload({
    required EntityDetails? entity,
    required String contactName,
    required String contactAbn,
    required bool contactGstRegistered,
    String contactAddress = '',
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<InvoiceLineItem> lineItems,
    required String Function(int) formatCents,
    BankAccountSummary? bankAccount,
  }) async {
    final doc = pw.Document();
    final dateLabel = DateFormat('dd/MM/yyyy').format(invoiceDate);
    final dueDateLabel =
        DateFormat('dd/MM/yyyy').format(invoiceDate.add(const Duration(days: 30)));

    final subtotalCents =
        lineItems.fold(0, (sum, item) => sum + item.amountCents);
    final gstCents =
        lineItems.fold(0, (sum, item) => sum + item.gstCents);
    final totalCents = subtotalCents + gstCents;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: PdfReportComponents.entityHeader(entity),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        invoiceNumber,
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 16),

              // ── Invoice meta + Bill To ───────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO',
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          contactName.isNotEmpty ? contactName : '—',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        if (contactAddress.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            contactAddress.trim(),
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey700),
                          ),
                        ],
                        if (contactAbn.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'ABN: ${Formatters.formatAbn(contactAbn)}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey700),
                          ),
                        ],
                        if (contactGstRegistered) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('GST Registered',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  // Invoice dates
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _metaRow('Invoice Date:', dateLabel),
                      pw.SizedBox(height: 4),
                      _metaRow('Due Date:', dueDateLabel),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // ── Line items table ─────────────────────────────────────────
              _buildTable(lineItems, formatCents, contactGstRegistered),

              pw.SizedBox(height: 20),

              // ── Totals ───────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _totalRow('Subtotal (ex GST):', formatCents(subtotalCents)),
                      if (gstCents > 0) ...[
                        pw.SizedBox(height: 4),
                        _totalRow('GST:', formatCents(gstCents)),
                      ],
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue900,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                        child: _totalRow(
                          'TOTAL DUE:',
                          formatCents(totalCents),
                          bold: true,
                          fontSize: 13,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // ── Payment details ──────────────────────────────────────────
              if (bankAccount != null) ...[
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Text('PAYMENT DETAILS',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    _paymentDetailCol('Bank', bankAccount.bankName),
                    pw.SizedBox(width: 24),
                    _paymentDetailCol('Account Name', entity?.name ?? bankAccount.accountName),
                    pw.SizedBox(width: 24),
                    _paymentDetailCol('BSB', bankAccount.bsbFormatted),
                    pw.SizedBox(width: 24),
                    _paymentDetailCol('Account Number', bankAccount.accountNumber),
                    pw.SizedBox(width: 24),
                    _paymentDetailCol('Payment Reference', invoiceNumber),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],

              // ── Footer ───────────────────────────────────────────────────
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              PdfReportComponents.pageFooter(
                  ctx, DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
            ],
          );
        },
      ),
    );

    final sanitized = invoiceNumber
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filename = '${sanitized.isNotEmpty ? sanitized : 'invoice'}.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  static pw.Widget _buildTable(
    List<InvoiceLineItem> items,
    String Function(int) fmt,
    bool showGst,
  ) {
    const cellStyle = pw.TextStyle(fontSize: 9);
    const headerDecoration = pw.BoxDecoration(color: PdfColors.blue900);

    final headers = [
      'DESCRIPTION',
      'AMOUNT (EX GST)',
      if (showGst) 'GST',
      'TOTAL',
    ];

    final rows = items.map((item) {
      final total = item.amountCents + item.gstCents;
      return [
        item.descriptionController.text.trim().isNotEmpty
            ? item.descriptionController.text.trim()
            : '—',
        fmt(item.amountCents),
        if (showGst) fmt(item.gstCents),
        fmt(total),
      ];
    }).toList();

    // Column widths: description takes remaining space
    final colWidths = [
      pw.FlexColumnWidth(3),
      pw.FlexColumnWidth(1.4),
      if (showGst) pw.FlexColumnWidth(1),
      pw.FlexColumnWidth(1.4),
    ];

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < colWidths.length; i++) i: colWidths[i],
      },
      border: pw.TableBorder(
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside:
            const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      children: [
        // Header row
        pw.TableRow(
          decoration: headerDecoration,
          children: headers.asMap().entries.map((e) {
            final isNumeric = e.key > 0;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: pw.Text(
                e.value,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold),
                textAlign:
                    isNumeric ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...rows.asMap().entries.map((rowEntry) {
          final isEven = rowEntry.key.isEven;
          return pw.TableRow(
            decoration: isEven
                ? null
                : const pw.BoxDecoration(color: PdfColors.grey50),
            children: rowEntry.value.asMap().entries.map((cellEntry) {
              final isNumeric = cellEntry.key > 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                child: pw.Text(
                  cellEntry.value,
                  style: cellStyle,
                  textAlign:
                      isNumeric ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _paymentDetailCol(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(width: 8),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 10,
    PdfColor color = PdfColors.black,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(label, style: style, textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 80,
          child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }
}
