import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/budget_entry.dart';
import '../models/general_ledger_entry.dart';

/// Builds the Budget vs Actual section for use inside a [pw.MultiPage].
///
/// Returns an empty list if no account has any budget or actual data for the
/// requested period, so callers can skip the page entirely.
class BudgetPdfReport {
  /// Builds Budget vs Actual widgets for [startMonth]..[endMonth] (1-based).
  static List<pw.Widget> build({
    required BudgetEntry? budget,
    required List<GeneralLedgerEntry> glAccounts,
    required Map<String, List<int>> actuals,
    required int startMonth,
    required int endMonth,
    required String periodLabel,
    required String Function(int) formatCents,
  }) {
    final incomeGl = glAccounts
        .where((g) => g.direction == GlDirection.moneyIn)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final expenseGl = glAccounts
        .where((g) => g.direction == GlDirection.moneyOut)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    int budgetFn(String glId) {
      if (budget == null) return 0;
      int sum = 0;
      for (int m = startMonth; m <= endMonth; m++) {
        sum += budget.amountFor(glId, m);
      }
      return sum;
    }

    int actualFn(String glId) {
      final months = actuals[glId];
      if (months == null) return 0;
      int sum = 0;
      for (int m = startMonth; m <= endMonth; m++) {
        sum += months[m - 1];
      }
      return sum;
    }

    final allGl = [...incomeGl, ...expenseGl];
    final hasData = allGl.any((g) => budgetFn(g.id) > 0 || actualFn(g.id) > 0);
    if (!hasData) return [];

    return [
      pw.Text('Budget vs Actual',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text(periodLabel,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),
      _section('Income', incomeGl, budgetFn, actualFn, formatCents),
      pw.SizedBox(height: 12),
      _section('Expenses', expenseGl, budgetFn, actualFn, formatCents,
          showColumnHeaders: true),
      pw.SizedBox(height: 8),
      _netRow(incomeGl, expenseGl, budgetFn, actualFn, formatCents),
    ];
  }

  static pw.Widget _section(
    String title,
    List<GeneralLedgerEntry> accounts,
    int Function(String) budgetFn,
    int Function(String) actualFn,
    String Function(int) fmt, {
    bool showColumnHeaders = false,
  }) {
    final rows =
        accounts.where((g) => budgetFn(g.id) > 0 || actualFn(g.id) > 0).toList();
    if (rows.isEmpty) return pw.SizedBox();

    final totalBudget = rows.fold(0, (s, g) => s + budgetFn(g.id));
    final totalActual = rows.fold(0, (s, g) => s + actualFn(g.id));

    final headerStyle =
        pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white);
    final cellStyle = const pw.TextStyle(fontSize: 9);
    final totalStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);

    const colWidths = {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(1.5),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
      4: pw.FlexColumnWidth(1),
    };

    pw.Widget headerCell(String text, {pw.TextAlign align = pw.TextAlign.right}) =>
        pw.Text(text, style: headerStyle, textAlign: align);

    pw.Widget cell(String text,
            {pw.TextAlign align = pw.TextAlign.right, pw.TextStyle? style}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: pw.Text(text, style: style ?? cellStyle, textAlign: align),
        );

    int variance(String glId) => actualFn(glId) - budgetFn(glId);
    String pctLabel(String glId) {
      final b = budgetFn(glId);
      if (b == 0) return '';
      final p = actualFn(glId) / b * 100;
      final raw = p > 999 ? '>999%' : '${p.toStringAsFixed(0)}%';
      return actualFn(glId) < b ? '($raw)' : raw;
    }

    final colHeaderStyle =
        pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.grey700);

    pw.Widget colHeaderCell(String text) =>
        pw.Text(text, style: colHeaderStyle, textAlign: pw.TextAlign.right);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (showColumnHeaders)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Table(
              columnWidths: colWidths,
              children: [
                pw.TableRow(children: [
                  pw.SizedBox(),
                  colHeaderCell('Budget'),
                  colHeaderCell('Actual'),
                  colHeaderCell('Variance'),
                  colHeaderCell('% of Budget'),
                ]),
              ],
            ),
          ),
        pw.Container(
          color: PdfColors.grey800,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: pw.Text(title,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white)),
        ),
        pw.Table(
          columnWidths: colWidths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey600),
              children: [
                headerCell('Account', align: pw.TextAlign.left),
                headerCell('Budget'),
                headerCell('Actual'),
                headerCell('Variance'),
                headerCell('%'),
              ],
            ),
            ...rows.map((g) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: rows.indexOf(g).isEven ? PdfColors.grey100 : PdfColors.white,
                  ),
                  children: [
                    cell(g.description, align: pw.TextAlign.left),
                    cell(fmt(budgetFn(g.id))),
                    cell(fmt(actualFn(g.id))),
                    cell(fmt(variance(g.id)),
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: variance(g.id) >= 0 ? PdfColors.green700 : PdfColors.red700,
                        )),
                    cell(pctLabel(g.id),
                        style: actualFn(g.id) < budgetFn(g.id)
                            ? pw.TextStyle(fontSize: 9, color: PdfColors.red700)
                            : null),
                  ],
                )),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: pw.Text('Total $title', style: totalStyle, textAlign: pw.TextAlign.left),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: pw.Text(fmt(totalBudget), style: totalStyle, textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: pw.Text(fmt(totalActual), style: totalStyle, textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: pw.Text(fmt(totalActual - totalBudget),
                      style: totalStyle, textAlign: pw.TextAlign.right),
                ),
                pw.SizedBox(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _netRow(
    List<GeneralLedgerEntry> income,
    List<GeneralLedgerEntry> expense,
    int Function(String) budgetFn,
    int Function(String) actualFn,
    String Function(int) fmt,
  ) {
    final budgetNet = income.fold<int>(0, (s, g) => s + budgetFn(g.id)) -
        expense.fold<int>(0, (s, g) => s + budgetFn(g.id));
    final actualNet = income.fold<int>(0, (s, g) => s + actualFn(g.id)) -
        expense.fold<int>(0, (s, g) => s + actualFn(g.id));
    final varNet = actualNet - budgetNet;
    final style = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);

    return pw.Container(
      color: PdfColors.grey800,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
              flex: 3,
              child: pw.Text('Net', style: style.copyWith(color: PdfColors.white))),
          pw.Expanded(
              flex: 2,
              child: pw.Text(fmt(budgetNet),
                  style: style.copyWith(color: PdfColors.white),
                  textAlign: pw.TextAlign.right)),
          pw.Expanded(
              flex: 2,
              child: pw.Text(fmt(actualNet),
                  style: style.copyWith(color: PdfColors.white),
                  textAlign: pw.TextAlign.right)),
          pw.Expanded(
              flex: 2,
              child: pw.Text(fmt(varNet),
                  style: style.copyWith(
                      color: varNet >= 0 ? PdfColors.green300 : PdfColors.red300),
                  textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 1, child: pw.SizedBox()),
        ],
      ),
    );
  }
}
