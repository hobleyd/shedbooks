import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pnl_data.dart';

class PnlPdfReport {
  static List<pw.Widget> build({
    required PnLData data,
    required String periodEndedLabel,
    required String Function(int) formatCents,
  }) {
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
      if (data.incomeLines.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text('No income recorded for this period',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        )
      else ...[
        ...data.incomeLines.map((l) => _pdfGlRow(l, isExpense: false, formatCents: formatCents)),
        _pdfSubtotalRow('Total Income', data.totalIncome, isExpense: false, formatCents: formatCents),
      ],
      pw.SizedBox(height: 10),

      // Expenses
      _pdfSectionHeader('Expenses'),
      pw.Divider(thickness: 0.3),
      if (data.expenseLines.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text('No expenses recorded for this period',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        )
      else ...[
        ...data.expenseLines.map((l) => _pdfGlRow(l, isExpense: true, formatCents: formatCents)),
        _pdfSubtotalRow('Total Expenses', data.totalExpenses, isExpense: true, formatCents: formatCents),
      ],
      pw.SizedBox(height: 4),
      pw.Divider(thickness: 1.5),

      // Net
      _pdfNetRow(data.netProfit, formatCents: formatCents),
      pw.SizedBox(height: 12),
      pw.Text(
        '${data.periodTransactions.length} transaction${data.periodTransactions.length == 1 ? '' : 's'}',
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

  static pw.Widget _pdfGlRow(GlLine line, {required bool isExpense, required String Function(int) formatCents}) {
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
        pw.Divider(thickness: 0.1, color: PdfColors.grey300),
      ],
    );
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
