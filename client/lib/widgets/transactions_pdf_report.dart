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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction_entry.dart';

class TransactionsPdfReport {
  static Map<int, pw.TableColumnWidth> get _columnWidths => {
        0: const pw.FixedColumnWidth(50),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
        4: const pw.FixedColumnWidth(55),
        5: const pw.FixedColumnWidth(65),
      };

  /// Builds a list of PDF widgets representing a transactions report for
  /// [periodLabel] (e.g. "January 2026"). Pass all transactions for the period;
  /// this method sorts and partitions them internally.
  static List<pw.Widget> build({
    required List<TransactionEntry> transactions,
    required Map<String, String> contactNames,
    required Map<String, String> glDescriptions,
    required String periodLabel,
    required String Function(int) formatCents,
  }) {
    final moneyIn = transactions.where((t) => t.isCredit).toList()
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    final moneyOut = transactions.where((t) => !t.isCredit).toList()
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    final totalIn = moneyIn.fold(0, (s, t) => s + t.totalAmount);
    final totalOut = moneyOut.fold(0, (s, t) => s + t.totalAmount);

    return [
      pw.Text(
        'Transaction Report',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        periodLabel,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 14),

      pw.Text('Money In',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _buildTable(moneyIn, contactNames, glDescriptions, false, formatCents),
      _subtotalRow('Total Money In', totalIn, false, formatCents),
      pw.SizedBox(height: 16),

      pw.Text('Money Out',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _buildTable(moneyOut, contactNames, glDescriptions, true, formatCents),
      _subtotalRow('Total Money Out', totalOut, true, formatCents),
    ];
  }

  static pw.Widget _buildTable(
    List<TransactionEntry> txns,
    Map<String, String> contactNames,
    Map<String, String> glDescriptions,
    bool isExpense,
    String Function(int) formatCents,
  ) {
    if (txns.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(
          isExpense ? 'No outgoings for this period.' : 'No income for this period.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Table(
      columnWidths: _columnWidths,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        _headerRow(),
        ...txns.map((t) => _dataRow(t, contactNames, glDescriptions, isExpense, formatCents)),
      ],
    );
  }

  static pw.TableRow _headerRow() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _cell('Date', bold: true),
        _cell('Contact', bold: true),
        _cell('Account', bold: true),
        _cell('Description', bold: true),
        _cell('Receipt', bold: true),
        _cell('Amount', bold: true, align: pw.TextAlign.right),
      ],
    );
  }

  static pw.TableRow _dataRow(
    TransactionEntry t,
    Map<String, String> contactNames,
    Map<String, String> glDescriptions,
    bool isExpense,
    String Function(int) formatCents,
  ) {
    final parts = t.transactionDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : t.transactionDate;
    final amountText = isExpense
        ? '(${formatCents(t.totalAmount)})'
        : formatCents(t.totalAmount);

    return pw.TableRow(
      children: [
        _cell(dateLabel),
        _cell(contactNames[t.contactId] ?? '—'),
        _cell(glDescriptions[t.generalLedgerId] ?? '—'),
        _cell(t.description),
        _cell(t.receiptNumber),
        _cell(amountText,
            align: pw.TextAlign.right,
            color: isExpense ? PdfColors.red700 : null),
      ],
    );
  }

  static pw.Widget _subtotalRow(
    String label,
    int cents,
    bool isExpense,
    String Function(int) formatCents,
  ) {
    final amountText = isExpense ? '(${formatCents(cents)})' : formatCents(cents);
    return pw.Container(
      color: PdfColors.grey100,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text(amountText,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: isExpense ? PdfColors.red700 : PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        textAlign: align,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }
}
