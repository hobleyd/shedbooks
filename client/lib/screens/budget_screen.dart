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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/budget_entry.dart';
import '../models/budget_import_row.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../widgets/budget_pdf_report.dart';
import '../widgets/pdf_report_components.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthNamesFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Budget entry and Budget vs Actual report screen.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  List<int> _availableYears = [];
  int _selectedYear = DateTime.now().year;
  BudgetEntry? _budget;
  List<GeneralLedgerEntry> _glAccounts = [];
  List<TransactionEntry> _allTransactions = [];
  EntityDetails? _entityDetails;

  // Controllers and focus nodes: glId → list of 12 (Jan–Dec).
  final Map<String, List<TextEditingController>> _controllers = {};
  final Map<String, List<FocusNode>> _focusNodes = {};
  bool _hasUnsavedChanges = false;

  late TabController _tabController;

  // Report state.
  int _reportMonth = DateTime.now().month;
  bool _reportYtd = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    _disposeFocusNodes();
    super.dispose();
  }

  void _disposeControllers() {
    for (final list in _controllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    _controllers.clear();
  }

  void _disposeFocusNodes() {
    for (final list in _focusNodes.values) {
      for (final n in list) {
        n.dispose();
      }
    }
    _focusNodes.clear();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/budgets'),
        client.get('/general-ledger'),
        client.get('/transactions'),
        client.get('/entity-details'),
      ]);

      if (!mounted) return;

      if (results[1].statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load general ledger';
          _loading = false;
        });
        return;
      }

      final years = (jsonDecode(results[0].body) as List).cast<int>();
      final glList = (jsonDecode(results[1].body) as List)
          .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final transactions = results[2].statusCode == 200
          ? (jsonDecode(results[2].body) as List)
              .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : <TransactionEntry>[];
      EntityDetails? entityDetails;
      if (results[3].statusCode == 200) {
        entityDetails = EntityDetails.fromJson(
            jsonDecode(results[3].body) as Map<String, dynamic>);
      }

      // Default to current year; fall back to latest available year.
      final now = DateTime.now();
      int year = now.year;
      if (years.isNotEmpty && !years.contains(year)) year = years.last;

      setState(() {
        _availableYears = years;
        _selectedYear = year;
        _glAccounts = glList;
        _allTransactions = transactions;
        _entityDetails = entityDetails;
        _loading = false;
      });

      await _loadBudget(year);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadBudget(int year) async {
    final client = context.read<ApiClient>();
    final res = await client.get('/budgets/$year');
    if (!mounted) return;

    BudgetEntry? budget;
    if (res.statusCode == 200) {
      budget = BudgetEntry.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } else {
      budget = BudgetEntry(year: year, lines: {});
    }

    _disposeControllers();
    _disposeFocusNodes();
    _initControllers(budget);
    _initFocusNodes();

    setState(() {
      _budget = budget;
      _hasUnsavedChanges = false;
    });
  }

  void _initControllers(BudgetEntry budget) {
    for (final gl in _glAccounts) {
      final months = budget.lines[gl.id] ?? List.filled(12, 0);
      _controllers[gl.id] = List.generate(12, (i) {
        final cents = i < months.length ? months[i] : 0;
        return TextEditingController(
          text: cents == 0 ? '' : _centsToDisplay(cents),
        );
      });
    }
  }

  void _initFocusNodes() {
    for (final gl in _glAccounts) {
      _focusNodes[gl.id] = List.generate(12, (monthIdx) {
        final node = FocusNode();
        node.addListener(() {
          if (node.hasFocus) {
            final ctrl = _controllers[gl.id]?[monthIdx];
            if (ctrl != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (node.hasFocus) {
                  ctrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: ctrl.text.length,
                  );
                }
              });
            }
          }
        });
        return node;
      });
    }
  }

  /// Returns GL ids in the same order they appear in the edit grid
  /// (income sorted by label, then expense sorted by label).
  List<String> _buildOrderedGlIds() {
    final income = _glAccounts
        .where((g) => g.direction == GlDirection.moneyIn)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final expense = _glAccounts
        .where((g) => g.direction == GlDirection.moneyOut)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return [...income.map((g) => g.id), ...expense.map((g) => g.id)];
  }

  void _moveFocus(String glId, int monthIdx, int rowDelta, int colDelta) {
    final orderedIds = _buildOrderedGlIds();
    final rowIdx = orderedIds.indexOf(glId);
    if (rowIdx == -1) return;

    int newRow = rowIdx + rowDelta;
    int newCol = monthIdx + colDelta;

    // Wrap columns into next/previous row (Tab-style).
    if (newCol > 11) {
      newCol = 0;
      newRow += 1;
    } else if (newCol < 0) {
      newCol = 11;
      newRow -= 1;
    }

    if (newRow < 0 || newRow >= orderedIds.length) return;
    _focusNodes[orderedIds[newRow]]?[newCol].requestFocus();
  }

  // ── Saving ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final lines = <Map<String, dynamic>>[];
      for (final gl in _glAccounts) {
        final ctrls = _controllers[gl.id];
        if (ctrls == null) continue;
        final months = ctrls.map((c) => _displayToCents(c.text)).toList();
        if (months.any((v) => v > 0)) {
          lines.add({'generalLedgerId': gl.id, 'months': months});
        }
      }

      final client = context.read<ApiClient>();
      final res = await client.put(
        '/budgets/$_selectedYear',
        jsonEncode({'lines': lines}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final updated = BudgetEntry.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        if (!_availableYears.contains(_selectedYear)) {
          setState(() {
            _availableYears = [..._availableYears, _selectedYear]..sort();
          });
        }
        setState(() {
          _budget = updated;
          _hasUnsavedChanges = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget saved')),
          );
        }
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['error'] as String? ?? 'Save failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBudget() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete budget'),
        content: Text('Delete the $_selectedYear budget? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final client = context.read<ApiClient>();
    await client.delete('/budgets/$_selectedYear');
    if (!mounted) return;

    final newYears = _availableYears.where((y) => y != _selectedYear).toList();
    final newYear = newYears.isNotEmpty ? newYears.last : DateTime.now().year;
    setState(() {
      _availableYears = newYears;
      _selectedYear = newYear;
    });
    await _loadBudget(newYear);
  }

  // ── Year navigation ────────────────────────────────────────────────────────

  Future<void> _selectYear(int year) async {
    if (year == _selectedYear) return;
    if (_hasUnsavedChanges) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Leave without saving?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Leave')),
          ],
        ),
      );
      if (leave != true) return;
    }
    setState(() => _selectedYear = year);
    await _loadBudget(year);
  }

  Future<void> _addYear() async {
    final controller = TextEditingController(
        text: (DateTime.now().year).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New budget year'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Year'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final y = int.tryParse(controller.text);
              if (y != null) Navigator.of(ctx).pop(y);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() => _selectedYear = result);
    await _loadBudget(result);
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _openImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final csvContent = utf8.decode(bytes);

    // Parse on server.
    if (!mounted) return;
    final client = context.read<ApiClient>();
    final parseRes = await client.post('/budgets/parse-import', csvContent);
    if (!mounted) return;

    if (parseRes.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to parse CSV')),
      );
      return;
    }

    final parsed = (jsonDecode(parseRes.body)['rows'] as List)
        .map((e) => BudgetImportRow.fromJson(e as Map<String, dynamic>))
        .toList();

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ImportDialog(
        rows: parsed,
        glAccounts: _glAccounts,
        year: _selectedYear,
      ),
    );
    if (confirmed != true || !mounted) return;
    await _loadBudget(_selectedYear);
    if (!mounted) return;
    if (!_availableYears.contains(_selectedYear)) {
      setState(() {
        _availableYears = [..._availableYears, _selectedYear]..sort();
      });
    }
  }

  // ── Actuals computation ────────────────────────────────────────────────────

  /// Returns glId → 12 monthly actual totals in cents for [_selectedYear].
  Map<String, List<int>> _computeActuals() {
    final actuals = <String, List<int>>{};
    for (final t in _allTransactions) {
      final parts = t.transactionDate.split('-');
      if (parts.length < 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != _selectedYear || m == null || m < 1 || m > 12) continue;
      actuals[t.generalLedgerId] ??= List.filled(12, 0);
      actuals[t.generalLedgerId]![m - 1] += t.totalAmount;
    }
    return actuals;
  }

  // ── PDF ────────────────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final actuals = _computeActuals();
    final entity = _entityDetails;
    final generated = Formatters.formatDateShort(DateTime.now());

    final startMonth = _reportYtd ? 1 : _reportMonth;
    final periodLabel = _reportYtd
        ? 'Year to Date to ${_monthNamesFull[_reportMonth - 1]} $_selectedYear'
        : '${_monthNamesFull[_reportMonth - 1]} $_selectedYear';

    final doc = pw.Document(title: 'Budget vs Actual - $_selectedYear');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 50),
      footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
      build: (ctx) => [
        PdfReportComponents.entityHeader(entity),
        pw.SizedBox(height: 8),
        pw.Text(
          'Budget vs Actual — $_selectedYear',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        ...BudgetPdfReport.build(
          budget: _budget,
          glAccounts: _glAccounts,
          actuals: actuals,
          startMonth: startMonth,
          endMonth: _reportMonth,
          periodLabel: periodLabel,
          formatCents: Formatters.formatCents,
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────

  static String _centsToDisplay(int cents) {
    if (cents == 0) return '';
    return (cents / 100).toStringAsFixed(2);
  }

  static int _displayToCents(String text) {
    final cleaned = text.replaceAll(RegExp(r'[,\$\s]'), '');
    if (cleaned.isEmpty) return 0;
    final value = double.tryParse(cleaned) ?? 0.0;
    return (value * 100).round().abs();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthState>().isAdmin;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isAdmin),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Report'),
              Tab(text: 'Budget Setup'),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_loadError != null)
            Expanded(child: _buildError())
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReportTab(),
                  _buildEditTab(isAdmin),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isAdmin) {
    return Row(
      children: [
        Text('Budget', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 24),
        _buildYearSelector(),
        const Spacer(),
        if (!_loading && _budget != null && isAdmin) ...[
          OutlinedButton.icon(
            onPressed: _openImport,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Import CSV'),
          ),
          const SizedBox(width: 8),
        ],
        if (!_loading) ...[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ],
    );
  }

  Widget _buildYearSelector() {
    final items = [
      ..._availableYears.map(
        (y) => DropdownMenuItem(value: y, child: Text('$y')),
      ),
    ];

    // Add current year if not present.
    final now = DateTime.now();
    if (!_availableYears.contains(now.year)) {
      items.add(DropdownMenuItem(
          value: now.year, child: Text('${now.year} (new)')));
    }

    final isAdmin = context.watch<AuthState>().isAdmin;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: _selectedYear,
          items: items,
          onChanged: (y) {
            if (y != null) _selectYear(y);
          },
          underline: const SizedBox(),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            tooltip: 'Add budget year',
            onPressed: _addYear,
          ),
          if (_availableYears.contains(_selectedYear))
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete budget',
              onPressed: _deleteBudget,
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
          Text(_loadError!,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ── Edit tab ───────────────────────────────────────────────────────────────

  Widget _buildEditTab(bool isAdmin) {
    final incomeGl = _glAccounts
        .where((g) => g.direction == GlDirection.moneyIn)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final expenseGl = _glAccounts
        .where((g) => g.direction == GlDirection.moneyOut)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Column(
      children: [
        if (isAdmin && _hasUnsavedChanges)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_outlined, size: 16),
                const SizedBox(width: 8),
                const Text('Unsaved changes'),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildGrid(incomeGl, expenseGl, isAdmin),
            ),
          ),
        ),
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Budget'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(
    List<GeneralLedgerEntry> incomeGl,
    List<GeneralLedgerEntry> expenseGl,
    bool isAdmin,
  ) {
    final cs = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context)
        .textTheme
        .labelSmall!
        .copyWith(fontWeight: FontWeight.bold);

    const nameWidth = 200.0;
    const monthWidth = 90.0;
    const totalWidth = 100.0;

    Widget headerCell(String text, {double width = monthWidth}) =>
        SizedBox(
          width: width,
          child: Text(text,
              textAlign: TextAlign.right, style: headerStyle),
        );

    Widget totalCell(int cents, {double width = monthWidth}) =>
        SizedBox(
          width: width,
          child: Text(
            cents == 0 ? '—' : Formatters.formatCents(cents),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        );

    Widget editCell(String glId, int monthIdx) {
      final ctrl = _controllers[glId]?[monthIdx];
      final focusNode = _focusNodes[glId]?[monthIdx];
      if (ctrl == null || focusNode == null) return SizedBox(width: monthWidth);
      return SizedBox(
        width: monthWidth,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final shift = HardwareKeyboard.instance.isShiftPressed;
            switch (event.logicalKey) {
              case LogicalKeyboardKey.tab:
                _moveFocus(glId, monthIdx, 0, shift ? -1 : 1);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.enter:
                _moveFocus(glId, monthIdx, shift ? -1 : 1, 0);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowUp:
                _moveFocus(glId, monthIdx, -1, 0);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowDown:
                _moveFocus(glId, monthIdx, 1, 0);
                return KeyEventResult.handled;
              default:
                return KeyEventResult.ignored;
            }
          },
          child: TextField(
            controller: ctrl,
            focusNode: focusNode,
            enabled: isAdmin,
            textAlign: TextAlign.right,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (!_hasUnsavedChanges) {
                setState(() => _hasUnsavedChanges = true);
              }
            },
          ),
        ),
      );
    }

    int rowBudgetTotal(String glId) {
      final ctrls = _controllers[glId];
      if (ctrls == null) return 0;
      return ctrls.fold(0, (s, c) => s + _displayToCents(c.text));
    }

    int colTotal(List<GeneralLedgerEntry> accounts, int monthIdx) =>
        accounts.fold(0, (s, g) {
          final ctrls = _controllers[g.id];
          if (ctrls == null || monthIdx >= ctrls.length) return s;
          return s + _displayToCents(ctrls[monthIdx].text);
        });

    Widget sectionHeader(String title) => Container(
          color: cs.primaryContainer,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer)),
              ),
              ...List.generate(
                  12,
                  (i) => SizedBox(
                      width: monthWidth,
                      child: Text(_monthNames[i],
                          textAlign: TextAlign.right,
                          style: headerStyle))),
              SizedBox(
                  width: totalWidth,
                  child: Text('Total',
                      textAlign: TextAlign.right,
                      style: headerStyle)),
            ],
          ),
        );

    Widget accountRow(GeneralLedgerEntry gl, Color bg) => Container(
          color: bg,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Padding(
                  padding: EdgeInsets.only(
                      left: glDepth(_glAccounts, gl.id) * 12.0),
                  child: Text(gl.description,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              ...List.generate(12, (i) => editCell(gl.id, i)),
              SizedBox(
                  width: totalWidth,
                  child: Text(
                    Formatters.formatCents(rowBudgetTotal(gl.id)),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  )),
            ],
          ),
        );

    Widget totalsRow(String label, List<GeneralLedgerEntry> accounts) =>
        Container(
          color: cs.surfaceContainerHighest,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Text('Total $label',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              ...List.generate(
                  12, (i) => totalCell(colTotal(accounts, i))),
              SizedBox(
                width: totalWidth,
                child: Text(
                  Formatters.formatCents(
                      accounts.fold(0,
                          (s, g) => s + rowBudgetTotal(g.id))),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column header row.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            SizedBox(
                width: nameWidth,
                child: Text('Account', style: headerStyle)),
            ...List.generate(
                12,
                (i) => SizedBox(
                    width: monthWidth,
                    child: Text(_monthNames[i],
                        textAlign: TextAlign.right,
                        style: headerStyle))),
            headerCell('Total', width: totalWidth),
          ]),
        ),
        sectionHeader('Income'),
        ...incomeGl.asMap().entries.map((e) => accountRow(
            e.value,
            e.key.isEven ? Colors.transparent : cs.surfaceContainerLow)),
        totalsRow('Income', incomeGl),
        const SizedBox(height: 8),
        sectionHeader('Expenses'),
        ...expenseGl.asMap().entries.map((e) => accountRow(
            e.value,
            e.key.isEven ? Colors.transparent : cs.surfaceContainerLow)),
        totalsRow('Expenses', expenseGl),
      ],
    );
  }

  // ── Report tab ─────────────────────────────────────────────────────────────

  Widget _buildReportTab() {
    return Column(
      children: [
        _buildReportControls(),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildReportTable(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportControls() {
    final now = DateTime.now();
    final maxMonth =
        _selectedYear < now.year ? 12 : now.month;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _reportMonth > 1
              ? () => setState(() => _reportMonth--)
              : null,
          tooltip: 'Previous month',
        ),
        Text(
          '${_monthNamesFull[_reportMonth - 1]} $_selectedYear',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _reportMonth < maxMonth
              ? () => setState(() => _reportMonth++)
              : null,
          tooltip: 'Next month',
        ),
        const SizedBox(width: 16),
        FilterChip(
          label: const Text('Year to Date'),
          selected: _reportYtd,
          onSelected: (v) => setState(() => _reportYtd = v),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _generatePdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('PDF'),
        ),
      ],
    );
  }

  Widget _buildReportTable() {
    final actuals = _computeActuals();
    final budget = _budget;
    final startMonth = _reportYtd ? 1 : _reportMonth;
    final endMonth = _reportMonth;

    final incomeGl = _glAccounts
        .where((g) => g.direction == GlDirection.moneyIn)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final expenseGl = _glAccounts
        .where((g) => g.direction == GlDirection.moneyOut)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    int budgetFor(String glId) {
      if (budget == null) return 0;
      int sum = 0;
      for (int m = startMonth; m <= endMonth; m++) {
        sum += budget.amountFor(glId, m);
      }
      return sum;
    }

    int actualFor(String glId) {
      final months = actuals[glId];
      if (months == null) return 0;
      int sum = 0;
      for (int m = startMonth; m <= endMonth; m++) {
        sum += months[m - 1];
      }
      return sum;
    }

    final cs = Theme.of(context).colorScheme;
    const nameWidth = 200.0;
    const numWidth = 110.0;

    Widget headerCell(String text) => SizedBox(
          width: numWidth,
          child: Text(text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12)),
        );

    Widget numCell(int cents,
        {Color? color, bool bold = false}) =>
        SizedBox(
          width: numWidth,
          child: Text(
            Formatters.formatCents(cents),
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal),
          ),
        );

    Widget varianceCell(int variance, {bool bold = false}) {
      final color = variance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
      return numCell(variance, color: color, bold: bold);
    }

    Widget pctCell(int budget, int actual) {
      final label = Formatters.budgetPctLabel(budget, actual);
      if (label.isEmpty) return const SizedBox(width: numWidth);
      final negative = actual < budget;
      return SizedBox(
        width: numWidth,
        child: Text(
          label,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            color: negative ? Colors.red.shade700 : null,
          ),
        ),
      );
    }

    Widget sectionLabel(String text) => Container(
          width: nameWidth,
          color: cs.primaryContainer,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer)),
        );

    Widget accountRow(GeneralLedgerEntry gl, Color bg) {
      final b = budgetFor(gl.id);
      final a = actualFor(gl.id);
      final v = a - b;
      // Use annual totals for visibility: don't hide an account just because
      // it has no budget/actuals for the currently selected period.
      final annualB = budget?.annualFor(gl.id) ?? 0;
      final annualA = actuals[gl.id]?.fold(0, (s, v) => s + v) ?? 0;
      if (annualB == 0 && annualA == 0) return const SizedBox();
      return Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            SizedBox(
                width: nameWidth,
                child: Padding(
                  padding: EdgeInsets.only(
                      left: glDepth(_glAccounts, gl.id) * 12.0),
                  child: Text(gl.description,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                )),
            numCell(b),
            numCell(a),
            varianceCell(v),
            pctCell(b, a),
          ],
        ),
      );
    }

    Widget totalsRow(
        String label, List<GeneralLedgerEntry> accounts) {
      final totalB =
          accounts.fold(0, (s, g) => s + budgetFor(g.id));
      final totalA =
          accounts.fold(0, (s, g) => s + actualFor(g.id));
      return Container(
        color: cs.surfaceContainerHighest,
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: nameWidth,
                child: Text('Total $label',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12))),
            numCell(totalB, bold: true),
            numCell(totalA, bold: true),
            varianceCell(totalA - totalB, bold: true),
            pctCell(totalB, totalA),
          ],
        ),
      );
    }

    final totalIncomeB =
        incomeGl.fold(0, (s, g) => s + budgetFor(g.id));
    final totalIncomeA =
        incomeGl.fold(0, (s, g) => s + actualFor(g.id));
    final totalExpenseB =
        expenseGl.fold(0, (s, g) => s + budgetFor(g.id));
    final totalExpenseA =
        expenseGl.fold(0, (s, g) => s + actualFor(g.id));
    final netB = totalIncomeB - totalExpenseB;
    final netA = totalIncomeA - totalExpenseA;

    Widget columnHeaders() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            const SizedBox(width: nameWidth),
            headerCell('Budget'),
            headerCell('Actual'),
            headerCell('Variance'),
            headerCell('% of Budget'),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Income section.
        columnHeaders(),
        Row(children: [
          sectionLabel('Income'),
          SizedBox(width: numWidth * 4),
        ]),
        ...incomeGl.asMap().entries.map((e) => accountRow(
            e.value,
            e.key.isEven
                ? Colors.transparent
                : cs.surfaceContainerLow)),
        totalsRow('Income', incomeGl),
        const SizedBox(height: 8),
        // Expenses section.
        columnHeaders(),
        Row(children: [
          sectionLabel('Expenses'),
          SizedBox(width: numWidth * 4),
        ]),
        ...expenseGl.asMap().entries.map((e) => accountRow(
            e.value,
            e.key.isEven
                ? Colors.transparent
                : cs.surfaceContainerLow)),
        totalsRow('Expenses', expenseGl),
        const SizedBox(height: 8),
        // Net row.
        Container(
          color: cs.primaryContainer,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Text('Net',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: cs.onPrimaryContainer)),
              ),
              numCell(netB, bold: true),
              numCell(netA, bold: true),
              varianceCell(netA - netB, bold: true),
              pctCell(netB, netA),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Import dialog ──────────────────────────────────────────────────────────

class _ImportDialog extends StatefulWidget {
  final List<BudgetImportRow> rows;
  final List<GeneralLedgerEntry> glAccounts;
  final int year;

  const _ImportDialog({
    required this.rows,
    required this.glAccounts,
    required this.year,
  });

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  bool _saveMappings = true;
  bool _confirming = false;
  String? _error;

  List<BudgetImportRow> get rows => widget.rows;

  Future<void> _confirm() async {
    // Rows without a GL selection are skipped rather than blocking the import.
    final submittable = rows.where((r) => r.selectedGlId != null).toList();
    if (submittable.isEmpty) {
      setState(() => _error = 'No rows have a GL account selected.');
      return;
    }

    setState(() {
      _confirming = true;
      _error = null;
    });

    try {
      final body = jsonEncode({
        'rows': submittable
            .map((r) => {
                  'externalCode': r.externalCode,
                  'externalName': r.externalName,
                  'generalLedgerId': r.selectedGlId,
                  'months': r.months,
                })
            .toList(),
        'saveMappings': _saveMappings,
      });

      final client = context.read<ApiClient>();
      final res = await client.post(
          '/budgets/${widget.year}/confirm-import', body);
      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        final msg = jsonDecode(res.body)['error'] as String? ??
            'Import failed';
        setState(() {
          _error = msg;
          _confirming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Import failed: $e';
          _confirming = false;
        });
      }
    }
  }

  /// Interleaves section headers between Money In and Money Out rows.
  List<Object> get _listItems {
    final items = <Object>[];
    bool addedMoneyIn = false;
    bool addedMoneyOut = false;
    for (final row in rows) {
      final isIn = row.direction == GlDirection.moneyIn;
      if (isIn && !addedMoneyIn) {
        items.add(const _SectionHeader('Money In'));
        addedMoneyIn = true;
      }
      if (!isIn && !addedMoneyOut) {
        items.add(const _SectionHeader('Money Out'));
        addedMoneyOut = true;
      }
      items.add(row);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
            maxWidth: 1100, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Map GL Accounts',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Match each imported account to a GL account in this system. '
                'High-confidence matches are pre-selected.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              // Table header.
              const Row(children: [
                Expanded(
                    child: Text('Account Description',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 12),
                SizedBox(
                    width: 100,
                    child: Text('Annual',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 16),
                SizedBox(
                    width: 320,
                    child: Text('GL Account',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _listItems.length,
                  itemBuilder: (ctx, i) {
                    final item = _listItems[i];
                    if (item is _SectionHeader) return _sectionHeaderWidget(item.label);
                    return _rowWidget(item as BudgetImportRow);
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _saveMappings,
                    onChanged: (v) =>
                        setState(() => _saveMappings = v ?? true),
                  ),
                  const Text('Remember these GL mappings for future imports'),
                  const Spacer(),
                  TextButton(
                    onPressed: _confirming
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _confirming ? null : _confirm,
                    child: _confirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Import'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeaderWidget(String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cs.primaryContainer,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _rowWidget(BudgetImportRow row) {
    final cs = Theme.of(context).colorScheme;
    final confidence = row.confidence;
    Color? confidenceColor;
    if (row.selectedGlId != null && confidence >= 0.8) {
      confidenceColor = Colors.green.shade600;
    } else if (row.selectedGlId != null && confidence >= 0.5) {
      confidenceColor = Colors.orange.shade600;
    }

    // Only show GL accounts matching the row's direction.
    final filteredGl = widget.glAccounts
        .where((g) => g.direction == row.direction)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.externalCode,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              Formatters.formatCents(row.annualTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: row.selectedGlId,
                    isExpanded: true,
                    hint: const Text('Select GL account'),
                    selectedItemBuilder: (ctx) => [
                      const Text('— skip this row —',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      ...filteredGl.map((g) => Text(
                            buildGlPath(widget.glAccounts, g.id),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          )),
                    ],
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('— skip this row —')),
                      ...filteredGl.map(
                        (g) => DropdownMenuItem(
                          value: g.id,
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: glDepth(widget.glAccounts, g.id) * 12.0),
                            child: Text(
                              g.description,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => row.selectedGlId = v),
                    underline: Container(
                      height: 1,
                      color: row.selectedGlId == null ? cs.error : cs.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (confidenceColor != null)
                  Icon(Icons.check_circle_outline,
                      size: 16, color: confidenceColor)
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader {
  final String label;
  const _SectionHeader(this.label);
}
