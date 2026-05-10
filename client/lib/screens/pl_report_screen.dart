import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';

enum _PeriodType { month, quarter, year }

class _GlLine {
  final GeneralLedgerEntry gl;
  int totalCents = 0;
  _GlLine(this.gl);
}

/// Profit & Loss report, navigable by month, quarter, or year.
class PlReportScreen extends StatefulWidget {
  const PlReportScreen({super.key});

  @override
  State<PlReportScreen> createState() => _PlReportScreenState();
}

class _PlReportScreenState extends State<PlReportScreen> {
  bool _loading = true;
  String? _loadError;

  List<TransactionEntry> _allTransactions = [];
  Map<String, GeneralLedgerEntry> _glMap = {};
  EntityDetails? _entityDetails;

  _PeriodType _periodType = _PeriodType.month;

  late int _year;
  late int _month;
  late int _quarter;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _quarter = (now.month - 1) ~/ 3 + 1;
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

      if (results[0].statusCode != 200 || results[1].statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load data';
          _loading = false;
        });
        return;
      }

      final transactions = (jsonDecode(results[0].body) as List)
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final glList = (jsonDecode(results[1].body) as List)
          .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      EntityDetails? entityDetails;
      if (results[2].statusCode == 200) {
        entityDetails = EntityDetails.fromJson(
            jsonDecode(results[2].body) as Map<String, dynamic>);
      }

      setState(() {
        _allTransactions = transactions;
        _glMap = {for (final g in glList) g.id: g};
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

  // ── Period navigation ──────────────────────────────────────────────────────

  bool get _canGoForward {
    final now = DateTime.now();
    switch (_periodType) {
      case _PeriodType.month:
        return _year < now.year || (_year == now.year && _month < now.month);
      case _PeriodType.quarter:
        final currentQ = (now.month - 1) ~/ 3 + 1;
        return _year < now.year || (_year == now.year && _quarter < currentQ);
      case _PeriodType.year:
        return _year < now.year;
    }
  }

  void _prev() => setState(() {
        switch (_periodType) {
          case _PeriodType.month:
            if (_month == 1) { _month = 12; _year--; } else { _month--; }
          case _PeriodType.quarter:
            if (_quarter == 1) { _quarter = 4; _year--; } else { _quarter--; }
          case _PeriodType.year:
            _year--;
        }
      });

  void _next() {
    if (!_canGoForward) return;
    setState(() {
      switch (_periodType) {
        case _PeriodType.month:
          if (_month == 12) { _month = 1; _year++; } else { _month++; }
        case _PeriodType.quarter:
          if (_quarter == 4) { _quarter = 1; _year++; } else { _quarter++; }
        case _PeriodType.year:
          _year++;
      }
    });
  }

  void _onPeriodTypeChanged(_PeriodType type) {
    final now = DateTime.now();
    setState(() {
      _periodType = type;
      _year = now.year;
      _month = now.month;
      _quarter = (now.month - 1) ~/ 3 + 1;
    });
  }

  // ── Period labels ──────────────────────────────────────────────────────────

  String get _periodShortLabel {
    switch (_periodType) {
      case _PeriodType.month: return '${_monthNames[_month]} $_year';
      case _PeriodType.quarter: return 'Q$_quarter $_year';
      case _PeriodType.year: return '$_year';
    }
  }

  String get _periodEndedLabel {
    switch (_periodType) {
      case _PeriodType.month:
        return 'For the month ended ${_lastDayOfMonth(_year, _month)} ${_monthNames[_month]} $_year';
      case _PeriodType.quarter:
        final endMonth = _quarter * 3;
        return 'For the quarter ended ${_lastDayOfMonth(_year, endMonth)} ${_monthNames[endMonth]} $_year';
      case _PeriodType.year:
        return 'For the year ended 31 December $_year';
    }
  }

  static int _lastDayOfMonth(int year, int month) {
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2) {
      final isLeap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    return days[month];
  }

  // ── Data filtering & grouping ──────────────────────────────────────────────

  List<TransactionEntry> get _periodTransactions => _allTransactions.where((t) {
        final parts = t.transactionDate.split('-');
        if (parts.length < 2) return false;
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y == null || m == null) return false;
        switch (_periodType) {
          case _PeriodType.month:
            return y == _year && m == _month;
          case _PeriodType.quarter:
            final start = (_quarter - 1) * 3 + 1;
            return y == _year && m >= start && m < start + 3;
          case _PeriodType.year:
            return y == _year;
        }
      }).toList();

  List<_GlLine> _groupByGl(List<TransactionEntry> txns, bool credits) {
    final map = <String, _GlLine>{};
    for (final t in txns.where((t) => t.isCredit == credits)) {
      final gl = _glMap[t.generalLedgerId];
      if (gl == null) continue;
      (map[gl.id] ??= _GlLine(gl)).totalCents += t.totalAmount;
    }
    return map.values.toList()
      ..sort((a, b) => a.gl.label.compareTo(b.gl.label));
  }

  // ── Formatting ─────────────────────────────────────────────────────────────

  String _formatCents(int cents) {
    final dollars = cents / 100;
    final parts = dollars.toStringAsFixed(2).split('.');
    final buf = StringBuffer();
    int c = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
      c++;
    }
    return '\$${buf.toString().split('').reversed.join()}.${parts[1]}';
  }

  String _formatAbn(String abn) {
    final d = abn.replaceAll(' ', '');
    if (d.length != 11) return abn;
    return '${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 8)} ${d.substring(8)}';
  }

  String _formatDateShort(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ── PDF generation ─────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final txns = _periodTransactions;
    final incomeLines = _groupByGl(txns, true);
    final expenseLines = _groupByGl(txns, false);
    final totalIncome = incomeLines.fold(0, (s, l) => s + l.totalCents);
    final totalExpenses = expenseLines.fold(0, (s, l) => s + l.totalCents);
    final net = totalIncome - totalExpenses;
    final isProfit = net >= 0;
    final entity = _entityDetails;
    final generated = _formatDateShort(DateTime.now());

    final doc = pw.Document(title: 'Profit & Loss - $_periodShortLabel');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 50),
      header: (ctx) {
        if (ctx.pageNumber == 1) return pw.SizedBox(height: 0);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${entity?.name ?? ''}  —  Profit & Loss  —  $_periodShortLabel (continued)',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
          ],
        );
      },
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated $generated',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
          ],
        ),
      ),
      build: (ctx) => [
        // Entity header
        if (entity != null) ...[
          pw.Text(entity.name,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(
            'ABN: ${_formatAbn(entity.abn)}  |  ${entity.incorporationIdentifier}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 14),
        ],
        pw.Text('Profit & Loss',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.Text(_periodEndedLabel,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 10),

        // Income
        _pdfSectionHeader('Income'),
        pw.Divider(thickness: 0.5),
        if (incomeLines.isEmpty)
          _pdfEmptyRow('No income recorded for this period')
        else ...[
          ...incomeLines.map((l) => _pdfGlRow(l, isExpense: false)),
          _pdfSubtotalRow('Total Income', totalIncome, isExpense: false),
        ],
        pw.SizedBox(height: 16),

        // Expenses
        _pdfSectionHeader('Expenses'),
        pw.Divider(thickness: 0.5),
        if (expenseLines.isEmpty)
          _pdfEmptyRow('No expenses recorded for this period')
        else ...[
          ...expenseLines.map((l) => _pdfGlRow(l, isExpense: true)),
          _pdfSubtotalRow('Total Expenses', totalExpenses, isExpense: true),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 2),

        // Net
        _pdfNetRow(net, isProfit),

        pw.SizedBox(height: 24),
        pw.Text(
          '${txns.length} transaction${txns.length == 1 ? '' : 's'}',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static const _pdfLabelWidth = 76.0;
  static const _pdfAmountWidth = 100.0;

  pw.Widget _pdfSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: _pdfLabelWidth,
            child: pw.Text('Code',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(
            width: _pdfAmountWidth,
            child: pw.Text('Amount',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfGlRow(_GlLine line, {required bool isExpense}) {
    final amountText = isExpense
        ? '(${_formatCents(line.totalCents)})'
        : _formatCents(line.totalCents);
    final amountColor = isExpense ? PdfColors.red700 : PdfColors.black;
    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: _pdfLabelWidth,
                child: pw.Text(line.gl.label,
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey700)),
              ),
              pw.Expanded(
                child: pw.Text(line.gl.description,
                    style: pw.TextStyle(fontSize: 9)),
              ),
              pw.SizedBox(
                width: _pdfAmountWidth,
                child: pw.Text(amountText,
                    style: pw.TextStyle(fontSize: 9, color: amountColor),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),
        pw.Divider(thickness: 0.3, color: PdfColors.grey300),
      ],
    );
  }

  pw.Widget _pdfSubtotalRow(String label, int cents,
      {required bool isExpense}) {
    final amountText =
        isExpense ? '(${_formatCents(cents)})' : _formatCents(cents);
    final amountColor = isExpense ? PdfColors.red700 : PdfColors.black;
    return pw.Container(
      color: PdfColors.grey100,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(width: _pdfLabelWidth),
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(
              width: _pdfAmountWidth,
              child: pw.Text(amountText,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: amountColor),
                  textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfNetRow(int net, bool isProfit) {
    final color = isProfit ? PdfColors.black : PdfColors.red700;
    final label = isProfit ? 'Net Profit' : 'Net Loss';
    final amount =
        isProfit ? _formatCents(net) : '(${_formatCents(net.abs())})';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(width: _pdfLabelWidth),
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ),
          pw.SizedBox(
            width: _pdfAmountWidth,
            child: pw.Text(amount,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: color),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfEmptyRow(String message) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Text(message,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildPeriodNav(),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            _buildError()
          else
            Expanded(child: SingleChildScrollView(child: _buildReport())),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text('Profit & Loss',
            style: Theme.of(context).textTheme.headlineMedium),
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

  Widget _buildPeriodNav() {
    return Row(
      children: [
        SegmentedButton<_PeriodType>(
          segments: const [
            ButtonSegment(value: _PeriodType.month, label: Text('Month')),
            ButtonSegment(value: _PeriodType.quarter, label: Text('Quarter')),
            ButtonSegment(value: _PeriodType.year, label: Text('Year')),
          ],
          selected: {_periodType},
          onSelectionChanged: (s) => _onPeriodTypeChanged(s.first),
          style: const ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _loading ? null : _prev,
          tooltip: 'Previous period',
        ),
        Text(_periodShortLabel,
            style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: (!_loading && _canGoForward) ? _next : null,
          tooltip: 'Next period',
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final txns = _periodTransactions;
    final incomeLines = _groupByGl(txns, true);
    final expenseLines = _groupByGl(txns, false);

    final totalIncome = incomeLines.fold(0, (s, l) => s + l.totalCents);
    final totalExpenses = expenseLines.fold(0, (s, l) => s + l.totalCents);
    final net = totalIncome - totalExpenses;
    final isProfit = net >= 0;

    const labelColWidth = 90.0;
    const amountWidth = 160.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodEndedLabel,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // ── Income ──────────────────────────────────────────────────────
          _buildSectionHeader('Income', labelColWidth, amountWidth),
          const Divider(height: 1),
          if (incomeLines.isEmpty)
            _buildEmptyRow('No income recorded for this period')
          else ...[
            ...incomeLines.map((l) =>
                _buildGlRow(l, labelColWidth, amountWidth, isExpense: false)),
            _buildSubtotalRow(
                'Total Income', totalIncome, labelColWidth, amountWidth,
                isExpense: false),
          ],

          const SizedBox(height: 24),

          // ── Expenses ─────────────────────────────────────────────────────
          _buildSectionHeader('Expenses', labelColWidth, amountWidth),
          const Divider(height: 1),
          if (expenseLines.isEmpty)
            _buildEmptyRow('No expenses recorded for this period')
          else ...[
            ...expenseLines.map((l) =>
                _buildGlRow(l, labelColWidth, amountWidth, isExpense: true)),
            _buildSubtotalRow(
                'Total Expenses', totalExpenses, labelColWidth, amountWidth,
                isExpense: true),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 2),

          // ── Net ───────────────────────────────────────────────────────────
          _buildNetRow(net, isProfit, labelColWidth, amountWidth),

          const SizedBox(height: 32),
          Text(
            '${txns.length} transaction${txns.length == 1 ? '' : 's'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black38),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, double labelColWidth, double amountWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: labelColWidth,
            child: Text('Code',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.black45)),
          ),
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: amountWidth,
            child: Text('Amount',
                style: Theme.of(context).textTheme.labelLarge,
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildGlRow(_GlLine line, double labelColWidth, double amountWidth,
      {required bool isExpense}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: labelColWidth,
                child: Text(
                  line.gl.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  line.gl.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                width: amountWidth,
                child: Text(
                  isExpense
                      ? '(${_formatCents(line.totalCents)})'
                      : _formatCents(line.totalCents),
                  style: TextStyle(
                    color: isExpense ? Colors.red.shade700 : Colors.black87,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSubtotalRow(String label, int cents, double labelColWidth,
      double amountWidth, {required bool isExpense}) {
    return Container(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            SizedBox(width: labelColWidth),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: amountWidth,
              child: Text(
                isExpense
                    ? '(${_formatCents(cents)})'
                    : _formatCents(cents),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.red.shade700 : Colors.black87,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetRow(
      int net, bool isProfit, double labelColWidth, double amountWidth) {
    final color = isProfit ? Colors.black87 : Colors.red.shade700;
    final label = isProfit ? 'Net Profit' : 'Net Loss';
    final amount = isProfit
        ? _formatCents(net)
        : '(${_formatCents(net.abs())})';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: labelColWidth),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ),
          SizedBox(
            width: amountWidth,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRow(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(message,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black45)),
    );
  }
}
