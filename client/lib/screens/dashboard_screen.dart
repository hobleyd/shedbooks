import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';

class _MonthSummary {
  final int month;
  int incomeCents = 0;
  int outgoingsCents = 0;

  _MonthSummary(this.month);

  int get netCents => incomeCents - outgoingsCents;
}

class _GlSummary {
  final GeneralLedgerEntry gl;
  int incomeCents = 0;
  int expensesCents = 0;

  _GlSummary(this.gl);

  int get netCents => incomeCents - expensesCents;
}

/// Dashboard showing income, outgoings and net by month, plus a
/// configurable GL account breakdown — both navigable by year.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _loadError;
  List<TransactionEntry> _allTransactions = [];
  List<GeneralLedgerEntry> _glEntries = [];
  List<_MonthSummary> _months = [];

  int _viewYear = DateTime.now().year;
  final List<String> _selectedGlIds = [];
  bool _prefSaving = false;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

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
        client.get('/dashboard-preferences'),
      ]);
      if (!mounted) return;

      if (results.any((r) => r.statusCode != 200)) {
        final bad = results.firstWhere((r) => r.statusCode != 200);
        setState(() {
          _loadError = 'Failed to load (${bad.statusCode})';
          _loading = false;
        });
        return;
      }

      final transactions = (jsonDecode(results[0].body) as List)
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final glEntries = (jsonDecode(results[1].body) as List)
          .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.description.compareTo(b.description));

      final prefJson =
          jsonDecode(results[2].body) as Map<String, dynamic>;
      final savedGlIds =
          (prefJson['selectedGlIds'] as List).cast<String>();

      setState(() {
        _allTransactions = transactions;
        _glEntries = glEntries;
        _selectedGlIds
          ..clear()
          ..addAll(savedGlIds.where(
              (id) => glEntries.any((g) => g.id == id)));
        _months = _buildMonthSummaries(transactions, _viewYear);
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

  List<_MonthSummary> _buildMonthSummaries(
      List<TransactionEntry> transactions, int year) {
    final now = DateTime.now();
    final maxMonth = year == now.year ? now.month : 12;

    final summaries = {
      for (var m = 1; m <= maxMonth; m++) m: _MonthSummary(m),
    };

    for (final t in transactions) {
      final parts = t.transactionDate.split('-');
      if (parts.length < 2) continue;
      final tYear = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (tYear != year || month == null || !summaries.containsKey(month)) {
        continue;
      }
      if (t.isCredit) {
        summaries[month]!.incomeCents += t.totalAmount;
      } else {
        summaries[month]!.outgoingsCents += t.totalAmount;
      }
    }

    return summaries.values.toList();
  }

  List<_GlSummary> _buildGlSummaries() {
    return _selectedGlIds.map((id) {
      final gl = _glEntries.firstWhere((g) => g.id == id);
      final summary = _GlSummary(gl);
      for (final t in _allTransactions) {
        if (t.generalLedgerId != id) continue;
        final parts = t.transactionDate.split('-');
        if (parts.isEmpty || int.tryParse(parts[0]) != _viewYear) continue;
        if (t.isCredit) {
          summary.incomeCents += t.totalAmount;
        } else {
          summary.expensesCents += t.totalAmount;
        }
      }
      return summary;
    }).toList();
  }

  Future<void> _savePreference() async {
    if (_prefSaving) return;
    setState(() => _prefSaving = true);
    try {
      await context.read<ApiClient>().put(
            '/dashboard-preferences',
            jsonEncode({'selectedGlIds': _selectedGlIds}),
          );
    } finally {
      if (mounted) setState(() => _prefSaving = false);
    }
  }

  bool get _canGoForwardYear => _viewYear < DateTime.now().year;

  void _prevYear() => setState(() {
        _viewYear--;
        _months = _buildMonthSummaries(_allTransactions, _viewYear);
      });

  void _nextYear() {
    if (_canGoForwardYear) {
      setState(() {
        _viewYear++;
        _months = _buildMonthSummaries(_allTransactions, _viewYear);
      });
    }
  }

  String _formatAmount(int cents) {
    final dollars = cents / 100;
    final parts = dollars.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
      count++;
    }
    return '\$${buffer.toString().split('').reversed.join()}.$decPart';
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
          const SizedBox(height: 24),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _loading ? null : _prevYear,
          tooltip: 'Previous year',
        ),
        Text('$_viewYear', style: Theme.of(context).textTheme.titleLarge),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: (!_loading && _canGoForwardYear) ? _nextYear : null,
          tooltip: 'Next year',
        ),
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthTable(),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),
          _buildGlBreakdownSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Monthly summary table ──────────────────────────────────────────────────

  Widget _buildMonthTable() {
    final totalIncome = _months.fold(0, (s, m) => s + m.incomeCents);
    final totalOutgoings = _months.fold(0, (s, m) => s + m.outgoingsCents);
    final totalNet = totalIncome - totalOutgoings;

    final headerStyle = Theme.of(context).textTheme.labelLarge;
    const colWidth = 160.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              const SizedBox(width: 140),
              SizedBox(
                  width: colWidth,
                  child: Text('Income', style: headerStyle, textAlign: TextAlign.right)),
              SizedBox(
                  width: colWidth,
                  child: Text('Outgoings', style: headerStyle, textAlign: TextAlign.right)),
              SizedBox(
                  width: colWidth,
                  child: Text('Net', style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1),
        ..._months.map((m) => _buildMonthRow(m, colWidth)),
        const Divider(height: 1, thickness: 2),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  'Total',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                  width: colWidth,
                  child: _amountText(totalIncome, isIncome: true, bold: true)),
              SizedBox(
                  width: colWidth,
                  child: _amountText(totalOutgoings, isIncome: false, bold: true)),
              SizedBox(width: colWidth, child: _netText(totalNet, bold: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthRow(_MonthSummary m, double colWidth) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(_monthNames[m.month],
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              SizedBox(
                  width: colWidth,
                  child: _amountText(m.incomeCents, isIncome: true)),
              SizedBox(
                  width: colWidth,
                  child: _amountText(m.outgoingsCents, isIncome: false)),
              SizedBox(width: colWidth, child: _netText(m.netCents)),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  // ── GL breakdown table ─────────────────────────────────────────────────────

  Widget _buildGlBreakdownSection() {
    final summaries = _buildGlSummaries();
    const colWidth = 160.0;
    const labelWidth = 280.0;
    final headerStyle = Theme.of(context).textTheme.labelLarge;
    final availableGl =
        _glEntries.where((g) => !_selectedGlIds.contains(g.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Account', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (summaries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                const SizedBox(width: 36),
                SizedBox(
                    width: labelWidth,
                    child: Text('Account', style: headerStyle)),
                SizedBox(
                    width: colWidth,
                    child: Text('Income',
                        style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(
                    width: colWidth,
                    child: Text('Expenses',
                        style: headerStyle, textAlign: TextAlign.right)),
                SizedBox(
                    width: colWidth,
                    child: Text('Net',
                        style: headerStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...summaries.map((s) => _buildGlRow(s, colWidth, labelWidth)),
          const Divider(height: 1, thickness: 2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                const SizedBox(width: 36),
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    'Total',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                    width: colWidth,
                    child: _amountText(
                        summaries.fold(0, (s, g) => s + g.incomeCents),
                        isIncome: true,
                        bold: true)),
                SizedBox(
                    width: colWidth,
                    child: _amountText(
                        summaries.fold(0, (s, g) => s + g.expensesCents),
                        isIncome: false,
                        bold: true)),
                SizedBox(
                    width: colWidth,
                    child: _netText(
                        summaries.fold(0, (s, g) => s + g.netCents),
                        bold: true)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (availableGl.isNotEmpty) _buildGlPicker(availableGl),
      ],
    );
  }

  Widget _buildGlRow(_GlSummary s, double colWidth, double labelWidth) {
    final isIn = s.gl.direction == GlDirection.moneyIn;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  color: Colors.red.shade400,
                  tooltip: 'Remove',
                  onPressed: _prefSaving
                      ? null
                      : () {
                          setState(() => _selectedGlIds.remove(s.gl.id));
                          _savePreference();
                        },
                ),
              ),
              SizedBox(
                width: labelWidth,
                child: Row(
                  children: [
                    Icon(
                      isIn
                          ? Icons.arrow_circle_down_outlined
                          : Icons.arrow_circle_up_outlined,
                      size: 14,
                      color:
                          isIn ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.gl.description,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  width: colWidth,
                  child: _amountText(s.incomeCents, isIncome: true)),
              SizedBox(
                  width: colWidth,
                  child: _amountText(s.expensesCents, isIncome: false)),
              SizedBox(width: colWidth, child: _netText(s.netCents)),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildGlPicker(List<GeneralLedgerEntry> available) {
    return Row(
      children: [
        const Icon(Icons.add, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        DropdownButton<String>(
          hint: const Text('Add GL account…'),
          value: null,
          underline: const SizedBox(),
          items: available.map((gl) {
            final isIn = gl.direction == GlDirection.moneyIn;
            return DropdownMenuItem(
              value: gl.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isIn
                        ? Icons.arrow_circle_down_outlined
                        : Icons.arrow_circle_up_outlined,
                    size: 14,
                    color: isIn ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(gl.description),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              setState(() => _selectedGlIds.add(id));
              _savePreference();
            }
          },
        ),
      ],
    );
  }

  // ── Shared text widgets ────────────────────────────────────────────────────

  Widget _amountText(int cents, {required bool isIncome, bool bold = false}) {
    final style = TextStyle(
      color: isIncome ? Colors.black87 : Colors.red.shade700,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final text = cents == 0
        ? '—'
        : isIncome
            ? _formatAmount(cents)
            : '(${_formatAmount(cents)})';
    return Text(text, style: style, textAlign: TextAlign.right);
  }

  Widget _netText(int netCents, {bool bold = false}) {
    final isNegative = netCents < 0;
    final style = TextStyle(
      color: isNegative ? Colors.red.shade700 : Colors.black87,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final text = netCents == 0
        ? '—'
        : isNegative
            ? '(${_formatAmount(netCents.abs())})'
            : _formatAmount(netCents);
    return Text(text, style: style, textAlign: TextAlign.right);
  }
}
