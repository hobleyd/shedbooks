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

import 'dart:convert';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/entity_details.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../widgets/pdf_report_components.dart';

class _YearData {
  final int year;
  int incomeCents = 0;
  int expensesCents = 0;
  int get netCents => incomeCents - expensesCents;

  _YearData(this.year);
}

/// Financial performance report showing annual income, expenses, and net
/// profit/loss as a grouped bar chart with PDF export.
class FinancialPerformanceScreen extends StatefulWidget {
  const FinancialPerformanceScreen({super.key});

  @override
  State<FinancialPerformanceScreen> createState() =>
      _FinancialPerformanceScreenState();
}

class _FinancialPerformanceScreenState
    extends State<FinancialPerformanceScreen> {
  bool _loading = true;
  String? _loadError;

  List<TransactionEntry> _allTransactions = [];
  EntityDetails? _entityDetails;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/transactions'),
        client.get('/general-ledger'),
        client.get('/entity-details'),
      ]);
      if (!mounted) return;

      if (results[0].statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load data';
          _loading = false;
        });
        return;
      }

      final transactions = (jsonDecode(results[0].body) as List)
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      EntityDetails? entityDetails;
      if (results[2].statusCode == 200) {
        entityDetails = EntityDetails.fromJson(
            jsonDecode(results[2].body) as Map<String, dynamic>);
      }

      setState(() {
        _allTransactions = transactions;
        _entityDetails = entityDetails;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  List<_YearData> get _yearData {
    final Map<int, _YearData> byYear = {};
    for (final TransactionEntry t in _allTransactions) {
      final List<String> parts = t.transactionDate.split('-');
      if (parts.isEmpty) continue;
      final int? year = int.tryParse(parts[0]);
      if (year == null) continue;
      final _YearData data = byYear[year] ??= _YearData(year);
      if (t.isCredit) {
        data.incomeCents += t.totalAmount;
      } else {
        data.expensesCents += t.totalAmount;
      }
    }
    final List<_YearData> sorted = byYear.values.toList()
      ..sort((_YearData a, _YearData b) => a.year.compareTo(b.year));
    return sorted;
  }

  Future<void> _generatePdf() async {
    final List<_YearData> data = _yearData;
    final EntityDetails? entity = _entityDetails;
    final String generated = Formatters.formatDateShort(DateTime.now());

    final int totalIncome = data.fold(0, (int s, _YearData d) => s + d.incomeCents);
    final int totalExpenses = data.fold(0, (int s, _YearData d) => s + d.expensesCents);
    final int totalNet = totalIncome - totalExpenses;

    pw.TextStyle netStyle(int net) => pw.TextStyle(
          fontSize: 9,
          color: net < 0 ? PdfColors.red700 : PdfColors.green800,
        );

    pw.TableRow dataRow(_YearData row) => pw.TableRow(
          children: [
            _pdfCell('${row.year}'),
            _pdfCell(Formatters.formatCents(row.incomeCents),
                align: pw.TextAlign.right),
            _pdfCell(Formatters.formatCents(row.expensesCents),
                align: pw.TextAlign.right),
            _pdfCell(
              row.netCents < 0
                  ? '(${Formatters.formatCents(row.netCents.abs())})'
                  : Formatters.formatCents(row.netCents),
              align: pw.TextAlign.right,
              style: netStyle(row.netCents),
            ),
          ],
        );

    final pw.TableRow totalsRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _pdfCell('Total',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        _pdfCell(Formatters.formatCents(totalIncome),
            align: pw.TextAlign.right,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        _pdfCell(Formatters.formatCents(totalExpenses),
            align: pw.TextAlign.right,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        _pdfCell(
          totalNet < 0
              ? '(${Formatters.formatCents(totalNet.abs())})'
              : Formatters.formatCents(totalNet),
          align: pw.TextAlign.right,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: totalNet < 0 ? PdfColors.red700 : PdfColors.green800,
          ),
        ),
      ],
    );

    final pw.Document doc =
        pw.Document(title: 'Financial Performance Report');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 50),
      footer: (pw.Context ctx) =>
          PdfReportComponents.pageFooter(ctx, generated),
      build: (pw.Context ctx) => [
        PdfReportComponents.entityHeader(entity),
        pw.Text(
          'Financial Performance Report',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Annual income, expenses, and net profit / (loss)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 14),
        _buildPdfLegend(),
        pw.SizedBox(height: 10),
        _buildPdfBarChart(data),
        pw.SizedBox(height: 24),
        pw.Text(
          'Summary',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(60),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell('Year',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                _pdfCell('Total Income',
                    align: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                _pdfCell('Total Expenses',
                    align: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                _pdfCell('Net Profit / (Loss)',
                    align: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
            ),
            ...data.map(dataRow),
            if (data.isNotEmpty) totalsRow,
          ],
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static pw.Widget _pdfCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    pw.TextStyle? style,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: style ?? const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            _buildError()
          else
            Expanded(
              child: SingleChildScrollView(child: _buildContent()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          'Financial Performance',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Spacer(),
        if (!_loading) ...[
          OutlinedButton.icon(
            onPressed: _generatePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _loadError!,
            style:
                TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final List<_YearData> data = _yearData;
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Text('No transaction data available.'),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Annual Overview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: _FinancialBarChart(data: data),
          ),
          const SizedBox(height: 40),
          Text(
            'Summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildTable(data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(const Color(0xFF43A047), 'Income'),
        const SizedBox(width: 20),
        _legendItem(const Color(0xFFE53935), 'Expenses'),
        const SizedBox(width: 20),
        _legendItem(const Color(0xFF1E88E5), 'Net Profit / (Loss)'),
      ],
    );
  }

  static Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildTable(List<_YearData> data) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int totalIncome =
        data.fold(0, (int s, _YearData d) => s + d.incomeCents);
    final int totalExpenses =
        data.fold(0, (int s, _YearData d) => s + d.expensesCents);
    final int totalNet = totalIncome - totalExpenses;

    return Table(
      border: TableBorder.all(color: colorScheme.outlineVariant, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(80),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration:
              BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: const [
            _Cell('Year', header: true),
            _Cell('Total Income', header: true, align: TextAlign.right),
            _Cell('Total Expenses', header: true, align: TextAlign.right),
            _Cell('Net Profit / (Loss)',
                header: true, align: TextAlign.right),
          ],
        ),
        for (final _YearData row in data)
          TableRow(
            children: [
              _Cell('${row.year}'),
              _Cell(Formatters.formatCents(row.incomeCents),
                  align: TextAlign.right),
              _Cell(Formatters.formatCents(row.expensesCents),
                  align: TextAlign.right),
              _Cell(
                row.netCents < 0
                    ? '(${Formatters.formatCents(row.netCents.abs())})'
                    : Formatters.formatCents(row.netCents),
                align: TextAlign.right,
                color: row.netCents < 0
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ],
          ),
        TableRow(
          decoration:
              BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            const _Cell('Total', header: true),
            _Cell(Formatters.formatCents(totalIncome),
                header: true, align: TextAlign.right),
            _Cell(Formatters.formatCents(totalExpenses),
                header: true, align: TextAlign.right),
            _Cell(
              totalNet < 0
                  ? '(${Formatters.formatCents(totalNet.abs())})'
                  : Formatters.formatCents(totalNet),
              header: true,
              align: TextAlign.right,
              color: totalNet < 0
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool header;
  final TextAlign align;
  final Color? color;

  const _Cell(
    this.text, {
    this.header = false,
    this.align = TextAlign.left,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 13,
          fontWeight: header ? FontWeight.w600 : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}

String _shortCents(int cents) {
  final double dollars = cents / 100;
  if (dollars >= 1000000) return '${(dollars / 1000000).toStringAsFixed(1)}M';
  if (dollars >= 1000) return '${(dollars / 1000).toStringAsFixed(0)}k';
  return dollars.toStringAsFixed(0);
}

pw.Widget _buildPdfLegend() {
  pw.Widget item(PdfColor color, String label) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 9,
            height: 9,
            decoration: pw.BoxDecoration(color: color),
          ),
          pw.SizedBox(width: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      );

  return pw.Row(
    children: [
      item(PdfColors.green600, 'Income'),
      pw.SizedBox(width: 14),
      item(PdfColors.red600, 'Expenses'),
      pw.SizedBox(width: 14),
      item(PdfColors.blue700, 'Net Profit'),
      pw.SizedBox(width: 14),
      item(PdfColors.orange700, 'Net Loss'),
    ],
  );
}

pw.Widget _buildPdfBarChart(List<_YearData> data) {
  if (data.isEmpty) return pw.SizedBox();

  const double leftPad = 44.0;
  const double rightPad = 4.0;
  const double topPad = 4.0;
  const double bottomPad = 18.0;
  const double totalWidth = 450.0;
  const double totalHeight = 160.0;
  const double chartWidth = totalWidth - leftPad - rightPad;
  const double chartHeight = totalHeight - topPad - bottomPad;

  double maxVal = 1;
  for (final _YearData d in data) {
    if (d.incomeCents > maxVal) maxVal = d.incomeCents.toDouble();
    if (d.expensesCents > maxVal) maxVal = d.expensesCents.toDouble();
    if (d.netCents.abs() > maxVal) maxVal = d.netCents.abs().toDouble();
  }

  const int gridSteps = 4;
  const pw.TextStyle labelStyle =
      pw.TextStyle(fontSize: 7, color: PdfColors.grey600);

  return pw.SizedBox(
    width: totalWidth,
    height: totalHeight,
    child: pw.Stack(
      children: [
        pw.Positioned(
          left: leftPad,
          top: topPad,
          child: pw.SizedBox(
            width: chartWidth,
            height: chartHeight,
            child: pw.CustomPaint(
              size: PdfPoint(chartWidth, chartHeight),
              painter: (PdfGraphics canvas, PdfPoint size) {
                // Grid lines (drawn before bars so bars appear on top)
                for (int i = 0; i <= gridSteps; i++) {
                  final double y = size.y * i / gridSteps;
                  canvas.setColor(
                      i == 0 ? PdfColors.grey500 : PdfColors.grey200);
                  canvas.moveTo(0, y);
                  canvas.lineTo(size.x, y);
                  canvas.strokePath();
                }

                // Y-axis
                canvas.setColor(PdfColors.grey400);
                canvas.moveTo(0, 0);
                canvas.lineTo(0, size.y);
                canvas.strokePath();

                // Bars
                final double groupWidth = size.x / data.length;
                const double groupPadFraction = 0.12;
                final double usableWidth =
                    groupWidth * (1 - 2 * groupPadFraction);
                const double barGap = 2.0;
                const int barCount = 3;
                final double barWidth =
                    (usableWidth - barGap * (barCount - 1)) / barCount;

                for (int i = 0; i < data.length; i++) {
                  final _YearData d = data[i];
                  final double groupX =
                      groupWidth * i + groupWidth * groupPadFraction;

                  void drawBar(int idx, int cents, PdfColor color) {
                    if (cents <= 0) return;
                    final double bh = (cents / maxVal) * size.y;
                    final double x = groupX + idx * (barWidth + barGap);
                    canvas.setColor(color);
                    canvas.drawRect(x, 0, barWidth, bh);
                    canvas.fillPath();
                  }

                  drawBar(0, d.incomeCents, PdfColors.green600);
                  drawBar(1, d.expensesCents, PdfColors.red600);
                  drawBar(
                    2,
                    d.netCents.abs(),
                    d.netCents >= 0 ? PdfColors.blue700 : PdfColors.orange700,
                  );
                }
              },
            ),
          ),
        ),

        // Y-axis labels
        for (int i = 0; i <= gridSteps; i++)
          pw.Positioned(
            top: topPad + chartHeight * (1 - i / gridSteps) - 5,
            left: 0,
            child: pw.SizedBox(
              width: leftPad - 4,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '\$${_shortCents((maxVal * i / gridSteps).round())}',
                  style: labelStyle,
                ),
              ),
            ),
          ),

        // Year labels
        for (int i = 0; i < data.length; i++)
          pw.Positioned(
            top: topPad + chartHeight + 4,
            left: leftPad + chartWidth * i / data.length,
            child: pw.SizedBox(
              width: chartWidth / data.length,
              child: pw.Center(
                child: pw.Text(
                  '${data[i].year}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _FinancialBarChart extends StatelessWidget {
  final List<_YearData> data;

  const _FinancialBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(
        data: data,
        textColor: Theme.of(context).colorScheme.onSurface,
        gridColor: Theme.of(context).colorScheme.outlineVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_YearData> data;
  final Color textColor;
  final Color gridColor;

  static const Color _incomeColor = Color(0xFF43A047);
  static const Color _expensesColor = Color(0xFFE53935);
  static const Color _netColor = Color(0xFF1E88E5);

  const _BarChartPainter({
    required this.data,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPad = 82.0;
    const double rightPad = 16.0;
    const double topPad = 12.0;
    const double bottomPad = 36.0;

    final double chartWidth = size.width - leftPad - rightPad;
    final double chartHeight = size.height - topPad - bottomPad;

    double maxPositive = 0;
    double maxNegative = 0;
    for (final _YearData d in data) {
      maxPositive = max(maxPositive, d.incomeCents.toDouble());
      maxPositive = max(maxPositive, d.expensesCents.toDouble());
      if (d.netCents > 0) maxPositive = max(maxPositive, d.netCents.toDouble());
      if (d.netCents < 0) {
        maxNegative = max(maxNegative, (-d.netCents).toDouble());
      }
    }
    if (maxPositive == 0 && maxNegative == 0) return;

    // Ensure there is always some positive scale even if all values zero
    if (maxPositive == 0) maxPositive = 1;

    final double totalRange = maxPositive + maxNegative;
    // zeroY = top of chart + positive portion of chart height
    final double zeroY =
        topPad + chartHeight * (maxPositive / totalRange);

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final Paint axisPaint = Paint()
      ..color = textColor.withAlpha(128)
      ..strokeWidth = 1;

    final TextPainter tp = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Y-axis grid lines and labels (positive side)
    const int gridSteps = 5;
    for (int i = 0; i <= gridSteps; i++) {
      final double value = maxPositive * i / gridSteps;
      final double y = zeroY - (value / totalRange) * chartHeight;

      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartWidth, y),
        gridPaint,
      );

      final String label =
          i == 0 ? '\$0' : '\$${_shortCents(value.round())}';
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          color: textColor.withAlpha(179),
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(leftPad - tp.width - 6, y - tp.height / 2),
      );
    }

    // Negative grid lines and labels
    if (maxNegative > 0) {
      const int negSteps = 2;
      for (int i = 1; i <= negSteps; i++) {
        final double value = maxNegative * i / negSteps;
        final double y = zeroY + (value / totalRange) * chartHeight;

        canvas.drawLine(
          Offset(leftPad, y),
          Offset(leftPad + chartWidth, y),
          gridPaint,
        );

        final String label = '-\$${_shortCents(value.round())}';
        tp.text = TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            color: textColor.withAlpha(179),
          ),
        );
        tp.layout();
        tp.paint(
          canvas,
          Offset(leftPad - tp.width - 6, y - tp.height / 2),
        );
      }
    }

    // Axes
    canvas.drawLine(
        Offset(leftPad, topPad), Offset(leftPad, topPad + chartHeight), axisPaint);
    canvas.drawLine(
        Offset(leftPad, zeroY), Offset(leftPad + chartWidth, zeroY), axisPaint);

    // Bars
    final double groupWidth = chartWidth / data.length;
    const int barCount = 3;
    const double groupPadFraction = 0.12;
    final double usableWidth = groupWidth * (1 - 2 * groupPadFraction);
    const double barGap = 3.0;
    final double barWidth =
        (usableWidth - barGap * (barCount - 1)) / barCount;

    for (int i = 0; i < data.length; i++) {
      final _YearData d = data[i];
      final double groupX = leftPad + groupWidth * i + groupWidth * groupPadFraction;

      void drawBar(int idx, int cents, Color color) {
        if (cents == 0) return;
        final bool negative = cents < 0;
        final double magnitude = cents.abs().toDouble();
        final double barHeight = (magnitude / totalRange) * chartHeight;
        final double x = groupX + idx * (barWidth + barGap);
        final Rect rect = negative
            ? Rect.fromLTWH(x, zeroY, barWidth, barHeight)
            : Rect.fromLTWH(x, zeroY - barHeight, barWidth, barHeight);

        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: negative ? Radius.zero : const Radius.circular(2),
            topRight: negative ? Radius.zero : const Radius.circular(2),
            bottomLeft:
                negative ? const Radius.circular(2) : Radius.zero,
            bottomRight:
                negative ? const Radius.circular(2) : Radius.zero,
          ),
          Paint()..color = color,
        );
      }

      drawBar(0, d.incomeCents, _incomeColor);
      drawBar(1, d.expensesCents, _expensesColor);
      drawBar(2, d.netCents, _netColor);

      // Year label
      tp.text = TextSpan(
        text: '${d.year}',
        style: TextStyle(fontSize: 11, color: textColor),
      );
      tp.layout();
      final double labelX =
          leftPad + groupWidth * i + groupWidth / 2 - tp.width / 2;
      tp.paint(canvas, Offset(labelX, topPad + chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.textColor != textColor;
}
