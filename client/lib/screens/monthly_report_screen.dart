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

import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../auth/auth_state.dart';
import '../models/bank_account_entry.dart';
import '../models/budget_entry.dart';
import '../models/closing_bank_balance_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/locked_month_entry.dart';
import '../models/pnl_data.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../services/reference_data_cache.dart';
import '../utils/formatters.dart';
import '../widgets/budget_pdf_report.dart';
import '../widgets/pdf_report_components.dart';
import '../widgets/pnl_pdf_report.dart';
import '../widgets/transactions_pdf_report.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthSummary {
  final int month;
  int incomeCents = 0;
  int outgoingsCents = 0;
  Map<String, int> bankBalances = {}; // bankAccountId -> balanceCents
  _MonthSummary(this.month);
  int get netCents => incomeCents - outgoingsCents;
  int get totalBalanceCents => bankBalances.values.fold(0, (a, b) => a + b);
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final TextEditingController _narrativeController = TextEditingController();
  List<TransactionEntry> _allTransactions = [];
  List<ClosingBankBalanceEntry> _closingBalances = [];
  BudgetEntry? _budget;
  bool _loading = true;
  List<PlatformFile> _bankStatements = [];

  // Entity details, GL accounts, bank accounts, locked months and contacts
  // are shared via the cache.
  EntityDetails? get _entityDetails => context.read<ReferenceDataCache>().entityDetails;
  List<BankAccountEntry> get _bankAccounts => context.read<ReferenceDataCache>().bankAccounts;
  List<LockedMonthEntry> get _lockedMonths => context.read<ReferenceDataCache>().lockedMonths;
  Map<String, GeneralLedgerEntry> get _glMap =>
      {for (final g in context.read<ReferenceDataCache>().glEntries) g.id: g};
  Map<String, String> get _contactNames =>
      {for (final c in context.read<ReferenceDataCache>().contacts) c.id: c.name};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = context.read<ApiClient>();
      final cache = context.read<ReferenceDataCache>();
      final now = DateTime.now();
      final reportYear = DateTime(now.year, now.month - 1).year;

      final results = await Future.wait([
        client.get('/transactions'),
        client.get('/closing-bank-balances'),
        client.get('/budgets/$reportYear'),
      ]);
      // Entity details, GL accounts, bank accounts, locked months and
      // contacts are required for the report; locked months and contacts
      // remain optional (their absence just leaves those views incomplete).
      await Future.wait([
        cache.refreshEntityDetails(),
        cache.refreshGl(),
        cache.refreshBankAccounts(),
      ]);
      unawaited(cache.refreshLockedMonths());
      unawaited(cache.refreshContacts());
      if (!mounted) return;

      // Only transactions/closing-balances (0-1) are required; budget (2) is optional.
      if (results.take(2).any((r) => r.statusCode != 200) ||
          cache.entityDetailsStatus == LoadStatus.error ||
          cache.glStatus == LoadStatus.error ||
          cache.bankAccountsStatus == LoadStatus.error) {
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _allTransactions = (jsonDecode(results[0].body) as List)
            .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _closingBalances = (jsonDecode(results[1].body) as List)
            .map((e) => ClosingBankBalanceEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        if (results[2].statusCode == 200) {
          _budget = BudgetEntry.fromJson(
            jsonDecode(results[2].body) as Map<String, dynamic>,
          );
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickBankStatements() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() {
        _bankStatements.addAll(result.files);
      });
    }
  }

  void _removeBankStatement(int index) {
    setState(() {
      _bankStatements.removeAt(index);
    });
  }

  void _reorderBankStatement(int oldIndex, int newIndex) {
    setState(() {
      final item = _bankStatements.removeAt(oldIndex);
      _bankStatements.insert(newIndex, item);
    });
  }

  @override
  void dispose() {
    _narrativeController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
    final progressNotifier = ValueNotifier<String>('Building report…');

    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: progressNotifier,
            builder: (_, msg, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Flexible(child: Text(msg)),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await _generatePdfWithProgress(progressNotifier);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      progressNotifier.dispose();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _generatePdfWithProgress(ValueNotifier<String> progress) async {
    final authState = context.read<AuthState>();
    final userName = authState.user?.name ?? authState.user?.email ?? 'Unknown';
    final entity = _entityDetails;
    final narrative = _narrativeController.text;

    final now = DateTime.now();
    final prevMonthDate = DateTime(now.year, now.month - 1);
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final reportMonthName = monthNames[prevMonthDate.month - 1];
    final reportYear = prevMonthDate.year;
    final reportMonth = prevMonthDate.month;
    final generated = Formatters.formatDateShort(DateTime.now());

    // Dashboard Data — locked months only (excludes in-progress months).
    final allDashboardMonths = _buildMonthSummaries(_allTransactions, _closingBalances, reportYear);
    final lockedKeys = _lockedMonths.map((l) => l.monthYear).toSet();
    final dashboardMonths = allDashboardMonths
        .where((m) => lockedKeys.contains('$reportYear-${m.month.toString().padLeft(2, '0')}'))
        .toList();

    // P&L Data for the report month
    final pnlData = PnLData.compute(
      allTransactions: _allTransactions,
      glMap: _glMap,
      filter: (t) {
        final parts = t.transactionDate.split('-');
        return parts.length >= 2 &&
            int.tryParse(parts[0]) == reportYear &&
            int.tryParse(parts[1]) == reportMonth;
      },
    );

    final doc = pw.Document(title: 'Monthly Report - $reportMonthName $reportYear');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30), // Smaller margin to fit more columns
      footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
      build: (ctx) => [
        // Header
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                entity?.name ?? 'ShedBooks',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                "Treasurer's Financial Report - $reportMonthName $reportYear",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'prepared by $userName',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),

        // Narrative
        if (narrative.isNotEmpty) ...[
          pw.Text('Narrative', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(narrative, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 24),
        ],

        // Dashboard Summary Table
        pw.Text('Monthly Performance Summary ($reportYear)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _buildDashboardTable(dashboardMonths, monthNames),
        pw.SizedBox(height: 24),
      ],
    ));

    // Append P&L on a separate page
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      header: (ctx) {
        if (ctx.pageNumber == 1) return pw.SizedBox(height: 0); 
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${entity?.name ?? ''}  -  Profit & Loss  -  $reportMonthName $reportYear (continued)',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
          ],
        );
      },
      footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
      build: (ctx) => [
        PdfReportComponents.entityHeader(entity),
        ...PnlPdfReport.build(
          data: pnlData,
          periodEndedLabel: 'For the month ended $reportMonthName $reportYear',
          formatCents: Formatters.formatCents,
        ),
      ],
    ));

    progress.value = 'Adding budget vs actual…';
    // Append Budget vs Actual
    final budgetActuals = _computeBudgetActuals(reportYear, reportMonth);
    final budgetWidgets = BudgetPdfReport.build(
      budget: _budget,
      glAccounts: _glMap.values.toList(),
      actuals: budgetActuals,
      startMonth: 1,
      endMonth: reportMonth,
      periodLabel: 'Year to Date to $reportMonthName $reportYear',
      formatCents: Formatters.formatCents,
    );
    if (budgetWidgets.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
        build: (ctx) => [
          PdfReportComponents.entityHeader(entity),
          ...budgetWidgets,
        ],
      ));
    }

    progress.value = 'Adding transactions…';
    // Append Transactions for the latest locked month
    if (lockedKeys.isNotEmpty) {
      final latestLockedKey = (lockedKeys.toList()..sort()).last;
      final llParts = latestLockedKey.split('-');
      final llYear = int.tryParse(llParts[0]);
      final llMonth = int.tryParse(llParts.length > 1 ? llParts[1] : '');
      if (llYear != null && llMonth != null) {
        final llMonthName = monthNames[llMonth - 1];
        final txnsForLatestLocked = _allTransactions
            .where((t) => t.transactionDate.startsWith(latestLockedKey))
            .toList();
        final glDescriptions = {for (final e in _glMap.entries) e.key: e.value.description};
        final txnWidgets = TransactionsPdfReport.build(
          transactions: txnsForLatestLocked,
          contactNames: _contactNames,
          glDescriptions: glDescriptions,
          periodLabel: '$llMonthName $llYear',
          formatCents: Formatters.formatCents,
        );
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
          build: (ctx) => [
            PdfReportComponents.entityHeader(entity),
            ...txnWidgets,
          ],
        ));
      }
    }

    // Append Bank Statements
    for (int i = 0; i < _bankStatements.length; i++) {
      final file = _bankStatements[i];
      progress.value = 'Processing ${file.name} (${i + 1} of ${_bankStatements.length})…';
      if (file.bytes == null) continue;
      await for (final page in Printing.raster(file.bytes!, dpi: 150)) {
        final image = await page.toPng();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.contain),
          ),
        ));
      }
    }

    progress.value = 'Finalizing…';
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(enableEventLoopBalancing: true),
    );
  }

  Map<String, List<int>> _computeBudgetActuals(int year, int upToMonth) {
    final actuals = <String, List<int>>{};
    for (final t in _allTransactions) {
      final parts = t.transactionDate.split('-');
      if (parts.length < 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != year || m == null || m < 1 || m > upToMonth) continue;
      actuals[t.generalLedgerId] ??= List.filled(12, 0);
      actuals[t.generalLedgerId]![m - 1] += t.totalAmount;
    }
    return actuals;
  }

  List<_MonthSummary> _buildMonthSummaries(
      List<TransactionEntry> transactions, List<ClosingBankBalanceEntry> balances, int year) {
    final now = DateTime.now();
    final maxMonth = year == now.year ? now.month : 12;
    final summaries = {for (var m = 1; m <= maxMonth; m++) m: _MonthSummary(m)};

    for (final t in transactions) {
      final parts = t.transactionDate.split('-');
      if (parts.length < 2) continue;
      final tYear = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (tYear != year || month == null || !summaries.containsKey(month)) continue;
      if (t.isCredit) {
        summaries[month]!.incomeCents += t.totalAmount;
      } else {
        summaries[month]!.outgoingsCents += t.totalAmount;
      }
    }

    for (final b in balances) {
      final parts = b.balanceDate.split('-');
      if (parts.length < 2) continue;
      final bYear = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (bYear != year || month == null || !summaries.containsKey(month)) continue;
      summaries[month]!.bankBalances[b.bankAccountId] = b.balanceCents;
    }

    // Cash-type accounts have no closing_bank_balances entries; compute a
    // running balance from all isCash-flagged transactions up to each month.
    for (final account in _bankAccounts.where((a) => a.accountType == BankAccountType.cash)) {
      for (final summary in summaries.values) {
        final yearMonth = '$year-${summary.month.toString().padLeft(2, '0')}';
        bool hasCash = false;
        int balance = 0;
        for (final t in transactions) {
          if (!t.isCash) continue;
          final txYearMonth = t.transactionDate.length >= 7 ? t.transactionDate.substring(0, 7) : '';
          if (txYearMonth.compareTo(yearMonth) <= 0) {
            hasCash = true;
            balance += t.isCredit ? t.totalAmount : -t.totalAmount;
          }
        }
        if (hasCash) summary.bankBalances[account.id] = balance;
      }
    }

    return summaries.values.toList();
  }

  pw.Widget _buildDashboardTable(List<_MonthSummary> months, List<String> monthNames) {
    final totalIncome = months.fold(0, (s, m) => s + m.incomeCents);
    final totalOutgoings = months.fold(0, (s, m) => s + m.outgoingsCents);
    final totalNet = totalIncome - totalOutgoings;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('Month'),
            _tableHeader('Income', align: pw.TextAlign.right),
            _tableHeader('Outgoings', align: pw.TextAlign.right),
            _tableHeader('Net', align: pw.TextAlign.right),
            ..._bankAccounts.map((a) => _tableHeader(a.accountName, align: pw.TextAlign.right)),
            _tableHeader('Total Balance', align: pw.TextAlign.right),
          ],
        ),
        ...months.map((m) => pw.TableRow(
              children: [
                _tableCell(monthNames[m.month - 1]),
                _tableCell(Formatters.formatCents(m.incomeCents), align: pw.TextAlign.right),
                _tableCell(Formatters.formatCents(m.outgoingsCents), align: pw.TextAlign.right),
                _tableCell(Formatters.formatCents(m.netCents),
                    align: pw.TextAlign.right,
                    color: m.netCents < 0 ? PdfColors.red700 : PdfColors.black),
                ..._bankAccounts.map((a) {
                  final bal = m.bankBalances[a.id];
                  return _tableCell(bal == null ? '-' : Formatters.formatCents(bal), align: pw.TextAlign.right);
                }),
                _tableCell(m.bankBalances.isEmpty ? '-' : Formatters.formatCents(m.totalBalanceCents),
                    align: pw.TextAlign.right,
                    fontWeight: pw.FontWeight.bold),
              ],
            )),
        // Footer Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
          children: [
            _tableCell('Total', fontWeight: pw.FontWeight.bold),
            _tableCell(Formatters.formatCents(totalIncome), align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
            _tableCell(Formatters.formatCents(totalOutgoings), align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold),
            _tableCell(Formatters.formatCents(totalNet),
                align: pw.TextAlign.right,
                fontWeight: pw.FontWeight.bold,
                color: totalNet < 0 ? PdfColors.red700 : PdfColors.black),
            ..._bankAccounts.map((_) => _tableCell('')),
            _tableCell(''),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, 
            textAlign: align,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor? color, pw.FontWeight? fontWeight}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text,
            textAlign: align, 
            style: pw.TextStyle(fontSize: 7, color: color ?? PdfColors.black, fontWeight: fontWeight)),
      );

  @override
  Widget build(BuildContext context) {
    context.watch<ReferenceDataCache>();
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authState = context.watch<AuthState>();
    final userName = authState.user?.name ?? authState.user?.email ?? 'Unknown';

    final now = DateTime.now();
    final prevMonthDate = DateTime(now.year, now.month - 1);
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final reportMonth = monthNames[prevMonthDate.month - 1];
    final reportYear = prevMonthDate.year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _entityDetails?.name ?? 'ShedBooks',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Treasurer's Financial Report - $reportMonth $reportYear",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'prepared by $userName',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Narrative',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _narrativeController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Enter narrative for the month...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bank Statements',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                if (_bankStatements.isNotEmpty)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: _reorderBankStatement,
                    children: _bankStatements
                        .asMap()
                        .entries
                        .map((e) => ListTile(
                              key: ObjectKey(e.value),
                              leading: ReorderableDragStartListener(
                                index: e.key,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.drag_handle, color: Colors.black38),
                                    SizedBox(width: 8),
                                    Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                                  ],
                                ),
                              ),
                              title: Text(e.value.name, style: const TextStyle(fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeBankStatement(e.key),
                              ),
                            ))
                        .toList(),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickBankStatements,
                  icon: const Icon(Icons.add),
                  label: const Text('Upload Bank Statements'),
                ),
                const SizedBox(height: 48),
                IconButton(
                  icon: const Icon(Icons.assignment_outlined, size: 48),
                  tooltip: 'Generate Report',
                  onPressed: _generatePdf,
                ),
                const Text('Generate'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
