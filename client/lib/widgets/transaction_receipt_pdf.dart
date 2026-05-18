import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../utils/formatters.dart';
import 'pdf_report_components.dart';

class TransactionReceiptPdf {
  static Future<void> generateAndDownload({
    required TransactionEntry transaction,
    required EntityDetails? entity,
    required ContactEntry? contact,
    required GeneralLedgerEntry? glAccount,
    required String Function(int) formatCents,
  }) async {
    final doc = pw.Document();

    final parts = transaction.transactionDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : transaction.transactionDate;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top half container
              pw.Container(
                height: PdfPageFormat.a4.height / 2 - 60,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(child: PdfReportComponents.entityHeader(entity)),
                        pw.SizedBox(width: 20),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('TRANSACTION RECEIPT',
                                style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.blue900)),
                            pw.SizedBox(height: 6),
                            pw.Text('Receipt #: ${transaction.receiptNumber}',
                                style: pw.TextStyle(
                                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 12),
                    
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(child: _infoField('Date', dateLabel)),
                        pw.Expanded(child: _infoField('Type', transaction.isCredit ? 'Money In' : 'Money Out')),
                        pw.Expanded(child: _infoField('Reference', transaction.receiptNumber)),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(child: _infoField('Contact', contact?.name ?? '—')),
                        pw.Expanded(child: _infoField('GL Account', glAccount?.description ?? '—')),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    
                    pw.Text('DESCRIPTION',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text(transaction.description.isNotEmpty ? transaction.description : '—', 
                        style: const pw.TextStyle(fontSize: 10)),
                    
                    pw.Spacer(),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 8),
                    
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _amountRow('Subtotal (ex GST):', formatCents(transaction.amount)),
                            pw.SizedBox(height: 4),
                            _amountRow('GST:', formatCents(transaction.gstAmount)),
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                              ),
                              child: _amountRow(
                                'TOTAL AMOUNT:', 
                                formatCents(transaction.totalAmount),
                                isBold: true,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Optional: Add a "Cut here" line or similar if desired, 
              // but for now we just leave the bottom half empty as requested.
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
              ),
              pw.Spacer(),
              PdfReportComponents.pageFooter(context, DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
            ],
          );
        },
      ),
    );

    final filename = 'receipt_${transaction.receiptNumber}_${transaction.transactionDate}.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  static pw.Widget _infoField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _amountRow(String label, String value, {bool isBold = false, double fontSize = 10}) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(label, style: style, textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(width: 20),
        pw.SizedBox(
          width: 80,
          child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }
}
