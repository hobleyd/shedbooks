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
import '../models/pnl_data.dart';
import '../models/transaction_entry.dart';

class PnlPdfReport {
  /// Builds the P&L report content.
  ///
  /// When [selectedGlIds] is non-empty, only the GL lines whose id is in the
  /// set are included — everything else is left out — and each included
  /// line is expanded to show its individual transactions. When
  /// [selectedGlIds] is empty the report is generated as normal: every line
  /// is shown, as a summary only.
  static List<pw.Widget> build({
    required PnLData data,
    required String periodEndedLabel,
    required String Function(int) formatCents,
    Set<String> selectedGlIds = const {},
  }) {
    final bool filtering = selectedGlIds.isNotEmpty;

    final List<GlLine> incomeLines = filtering
        ? data.incomeLines.where((l) => selectedGlIds.contains(l.gl.id)).toList()
        : data.incomeLines;
    final List<GlLine> expenseLines = filtering
        ? data.expenseLines.where((l) => selectedGlIds.contains(l.gl.id)).toList()
        : data.expenseLines;

    final int totalIncome =
        filtering ? incomeLines.fold(0, (s, l) => s + l.totalCents) : data.totalIncome;
    final int totalExpenses =
        filtering ? expenseLines.fold(0, (s, l) => s + l.totalCents) : data.totalExpenses;
    final int netProfit = filtering ? totalIncome - totalExpenses : data.netProfit;
    final int transactionCount = filtering
        ? incomeLines.fold(0, (s, l) => s + l.transactions.length) +
            expenseLines.fold(0, (s, l) => s + l.transactions.length)
        : data.periodTransactions.length;

    final String noIncomeMessage =
        filtering ? 'No selected income records for this period' : 'No income recorded for this period';
    final String noExpensesMessage = filtering
        ? 'No selected expense records for this period'
        : 'No expenses recorded for this period';

    return [
      pw.Text('Profit & Loss Report',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text(periodEndedLabel,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.0),
      pw.SizedBox(height: 5),

      // Income
      _pdfSectionHeader('Income'),
      pw.Divider(thickness: 0.3),
      if (incomeLines.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(noIncomeMessage,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        )
      else ...[
        ...incomeLines.map((l) => _pdfGlRow(l,
            isExpense: false, formatCents: formatCents, showDetails: filtering)),
        _pdfSubtotalRow('Total Income', totalIncome, isExpense: false, formatCents: formatCents),
      ],
      pw.SizedBox(height: 10),

      // Expenses
      _pdfSectionHeader('Expenses'),
      pw.Divider(thickness: 0.3),
      if (expenseLines.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(noExpensesMessage,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        )
      else ...[
        ...expenseLines.map((l) => _pdfGlRow(l,
            isExpense: true, formatCents: formatCents, showDetails: filtering)),
        _pdfSubtotalRow('Total Expenses', totalExpenses, isExpense: true, formatCents: formatCents),
      ],
      pw.SizedBox(height: 4),
      pw.Divider(thickness: 1.5),

      // Net
      _pdfNetRow(netProfit, formatCents: formatCents),
      pw.SizedBox(height: 12),
      pw.Text(
        '$transactionCount transaction${transactionCount == 1 ? '' : 's'}',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
      ),
    ];
  }

  static pw.Widget _pdfSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
              width: 60,
              child: pw.Text('Code',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
          pw.Expanded(
              child: pw.Text(title,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(
              width: 80,
              child: pw.Text('Amount',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static pw.Widget _pdfGlRow(GlLine line,
      {required bool isExpense, required String Function(int) formatCents, bool showDetails = false}) {
    final amountText =
        isExpense ? '(${formatCents(line.totalCents)})' : formatCents(line.totalCents);
    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(
            children: [
              pw.SizedBox(
                  width: 60,
                  child: pw.Text(line.gl.label,
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
              pw.Expanded(
                  child: pw.Text(line.gl.description, style: const pw.TextStyle(fontSize: 8))),
              pw.SizedBox(
                  width: 80,
                  child: pw.Text(amountText,
                      style: pw.TextStyle(
                          fontSize: 8, color: isExpense ? PdfColors.red700 : PdfColors.black),
                      textAlign: pw.TextAlign.right)),
            ],
          ),
        ),
        if (showDetails) _pdfTransactionDetails(line.transactions, isExpense: isExpense, formatCents: formatCents),
        pw.Divider(thickness: 0.1, color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget _pdfTransactionDetails(List<TransactionEntry> transactions,
      {required bool isExpense, required String Function(int) formatCents}) {
    final List<TransactionEntry> sorted = List<TransactionEntry>.from(transactions)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(60, 1, 0, 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.SizedBox(
                  width: 48,
                  child: pw.Text('Date',
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500))),
              pw.SizedBox(
                  width: 56,
                  child: pw.Text('Receipt',
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500))),
              pw.Expanded(
                  child: pw.Text('Description',
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500))),
              pw.SizedBox(
                  width: 60,
                  child: pw.Text('Amount',
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
                      textAlign: pw.TextAlign.right)),
            ],
          ),
          ...sorted.map((t) => _pdfTransactionRow(t, isExpense: isExpense, formatCents: formatCents)),
        ],
      ),
    );
  }

  static pw.Widget _pdfTransactionRow(TransactionEntry t,
      {required bool isExpense, required String Function(int) formatCents}) {
    final amountText = isExpense ? '(${formatCents(t.totalAmount)})' : formatCents(t.totalAmount);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
              width: 48,
              child: pw.Text(_formatIsoDate(t.transactionDate),
                  style: const pw.TextStyle(fontSize: 6.5))),
          pw.SizedBox(
              width: 56,
              child: pw.Text(t.receiptNumber, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700))),
          pw.Expanded(
              child: pw.Text(t.description.isEmpty ? '—' : t.description,
                  style: const pw.TextStyle(fontSize: 6.5))),
          pw.SizedBox(
              width: 60,
              child: pw.Text(amountText,
                  style: pw.TextStyle(
                      fontSize: 6.5, color: isExpense ? PdfColors.red700 : PdfColors.black),
                  textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static String _formatIsoDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  static pw.Widget _pdfSubtotalRow(String label, int cents, {required bool isExpense, required String Function(int) formatCents}) {
    final amountText = isExpense ? '(${formatCents(cents)})' : formatCents(cents);
    return pw.Container(
      color: PdfColors.grey100,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 60),
          pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(
              width: 80,
              child: pw.Text(amountText,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: isExpense ? PdfColors.red700 : PdfColors.black),
                  textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static pw.Widget _pdfNetRow(int net, {required String Function(int) formatCents}) {
    final isProfit = net >= 0;
    final color = isProfit ? PdfColors.black : PdfColors.red700;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 60),
          pw.Expanded(
            child: pw.Text(isProfit ? 'Net Profit' : 'Net Loss',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
          ),
          pw.SizedBox(
            width: 80,
            child: pw.Text(isProfit ? formatCents(net) : '(${formatCents(net.abs())})',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }
}
