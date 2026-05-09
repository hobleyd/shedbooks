import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      ]);
      if (!mounted) return;

      if (results.any((r) => r.statusCode != 200)) {
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

      setState(() {
        _allTransactions = transactions;
        _glMap = {for (final g in glList) g.id: g};
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
      // Reset to current period when switching type.
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
      ..sort((a, b) => a.gl.description.compareTo(b.gl.description));
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
        if (!_loading)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
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

    const amountWidth = 160.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
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
          _buildSectionHeader('Income', amountWidth),
          const Divider(height: 1),
          if (incomeLines.isEmpty)
            _buildEmptyRow('No income recorded for this period')
          else ...[
            ...incomeLines.map((l) => _buildGlRow(l, amountWidth, isExpense: false)),
            _buildSubtotalRow('Total Income', totalIncome, amountWidth,
                isExpense: false),
          ],

          const SizedBox(height: 24),

          // ── Expenses ─────────────────────────────────────────────────────
          _buildSectionHeader('Expenses', amountWidth),
          const Divider(height: 1),
          if (expenseLines.isEmpty)
            _buildEmptyRow('No expenses recorded for this period')
          else ...[
            ...expenseLines.map((l) => _buildGlRow(l, amountWidth, isExpense: true)),
            _buildSubtotalRow('Total Expenses', totalExpenses, amountWidth,
                isExpense: true),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 2),

          // ── Net ───────────────────────────────────────────────────────────
          _buildNetRow(net, isProfit, amountWidth),

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

  Widget _buildSectionHeader(String title, double amountWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: amountWidth,
            child: Text(
              'Amount',
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlRow(_GlLine line, double amountWidth, {required bool isExpense}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
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

  Widget _buildSubtotalRow(
      String label, int cents, double amountWidth, {required bool isExpense}) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(60),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
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

  Widget _buildNetRow(int net, bool isProfit, double amountWidth) {
    final color = isProfit ? Colors.black87 : Colors.red.shade700;
    final label = isProfit ? 'Net Profit' : 'Net Loss';
    final amount = isProfit
        ? _formatCents(net)
        : '(${_formatCents(net.abs())})';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
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
