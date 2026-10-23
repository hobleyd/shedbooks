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

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/reference_data_cache.dart';
import '../utils/formatters.dart';
import '../widgets/pdf_report_components.dart';

/// BAS (Business Activity Statement) report screen.
class BasReportScreen extends StatefulWidget {
  const BasReportScreen({super.key});

  @override
  State<BasReportScreen> createState() => _BasReportScreenState();
}

class _BasReportScreenState extends State<BasReportScreen> {
  bool _loading = true;
  String? _loadError;

  List<TransactionEntry> _allTransactions = [];
  Map<String, GeneralLedgerEntry> _glMap = {};
  List<GeneralLedgerEntry> _glEntries = [];
  Map<String, ContactEntry> _contactMap = {};
  EntityDetails? _entityDetails;

  late int _quarter;
  late int _year;

  static const _quarterMonthNames = {
    1: "January - March",
    2: "April - June",
    3: "July - September",
    4: "October - December",
  };

  @override
  void initState() {
    super.initState();
    final defaultQ = _previousQuarter();
    _quarter = defaultQ.quarter;
    _year = defaultQ.year;
    _load();
  }

  static ({int quarter, int year}) _previousQuarter() {
    final now = DateTime.now();
    final currentQ = (now.month - 1) ~/ 3 + 1;
    if (currentQ == 1) return (quarter: 4, year: now.year - 1);
    return (quarter: currentQ - 1, year: now.year);
  }

  bool get _canGoForward {
    final now = DateTime.now();
    final currentQ = (now.month - 1) ~/ 3 + 1;
    return _year < now.year || (_year == now.year && _quarter < currentQ);
  }

  void _prevQuarter() => setState(() {
        if (_quarter == 1) {
          _quarter = 4;
          _year--;
        } else {
          _quarter--;
        }
      });

  void _nextQuarter() {
    if (!_canGoForward) return;
    setState(() {
      if (_quarter == 4) {
        _quarter = 1;
        _year++;
      } else {
        _quarter++;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cache = context.read<ReferenceDataCache>();
      await Future.wait([
        cache.refreshTransactions(),
        cache.refreshGl(),
        cache.refreshEntityDetails(),
        cache.refreshContacts(),
      ]);
      if (!mounted) return;

      if (cache.transactionsStatus == LoadStatus.error ||
          cache.glStatus == LoadStatus.error) {
        setState(() {
          _loadError = 'Failed to load data';
          _loading = false;
        });
        return;
      }

      setState(() {
        _allTransactions = cache.transactions;
        _glMap = {for (final g in cache.glEntries) g.id: g};
        _glEntries = cache.glEntries;
        _contactMap = {for (final c in cache.contacts) c.id: c};
        _entityDetails = cache.entityDetails;
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

  // ── Quarter filtering ──────────────────────────────────────────────────────

  List<TransactionEntry> get _quarterTransactions {
    final startMonth = (_quarter - 1) * 3 + 1;
    return _allTransactions.where((t) {
      final parts = t.transactionDate.split('-');
      if (parts.length < 2) return false;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      return y == _year && m != null && m >= startMonth && m < startMonth + 3;
    }).toList();
  }

  // ── BAS computations ───────────────────────────────────────────────────────

  bool _isGstApplicable(TransactionEntry t) =>
      _glMap[t.generalLedgerId]?.gstApplicable ?? false;

  /// Transactions that make up G1: all credit (money-in) transactions.
  List<TransactionEntry> _g1Transactions(List<TransactionEntry> txns) =>
      txns.where((t) => t.isCredit).toList();

  /// Transactions that make up 1A: GST-applicable credit transactions.
  List<TransactionEntry> _oneATransactions(List<TransactionEntry> txns) =>
      txns.where((t) => t.isCredit && _isGstApplicable(t)).toList();

  /// Transactions that make up 1B: GST-applicable debit transactions.
  List<TransactionEntry> _oneBTransactions(List<TransactionEntry> txns) =>
      txns.where((t) => !t.isCredit && _isGstApplicable(t)).toList();

  /// G1: Total sales — all credit (money-in) transaction totals.
  int _computeG1(List<TransactionEntry> txns) =>
      _g1Transactions(txns).fold(0, (s, t) => s + t.totalAmount);

  /// 1A: GST on sales — GST component of GST-applicable credit transactions.
  int _compute1A(List<TransactionEntry> txns) =>
      _oneATransactions(txns).fold(0, (s, t) => s + t.gstAmount);

  /// 1B: GST on purchases — GST component of GST-applicable debit transactions.
  int _compute1B(List<TransactionEntry> txns) =>
      _oneBTransactions(txns).fold(0, (s, t) => s + t.gstAmount);

  // ── Period label ───────────────────────────────────────────────────────────

  String get _periodLabel {
    final startMonth = (_quarter - 1) * 3 + 1;
    final endMonth = startMonth + 2;
    final endDay = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][endMonth - 1];
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '1 ${months[startMonth]} to $endDay ${months[endMonth]} $_year';
  }

  // ── PDF generation ─────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final txns = _quarterTransactions;
    final g1 = _computeG1(txns);
    final oneA = _compute1A(txns);
    final oneB = _compute1B(txns);
    final netGst = oneA - oneB;
    final isPayable = netGst >= 0;
    final entity = _entityDetails;
    final generated = Formatters.formatDateShort(DateTime.now());

    final doc = pw.Document(title: 'BAS Q$_quarter $_year');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(50),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfReportComponents.entityHeader(entity),
          pw.Text('Business Activity Statement',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            "Q$_quarter $_year - ${_quarterMonthNames[_quarter]}",
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text('Period: $_periodLabel',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 12),

          // GST on Sales
          _basPdfSectionTitle('GST on Sales'),
          pw.Divider(thickness: 0.5),
          _basPdfRow('G1', 'Total sales',
              'All income for the quarter', g1,
              highlight: false),
          _basPdfRow('1A', 'GST on sales',
              'GST collected on GST-applicable income', oneA,
              highlight: true),
          pw.SizedBox(height: 14),

          // GST on Purchases
          _basPdfSectionTitle('GST on Purchases'),
          pw.Divider(thickness: 0.5),
          _basPdfRow('1B', 'GST on purchases',
              'GST paid on GST-applicable expenses', oneB,
              highlight: true),
          pw.SizedBox(height: 16),

          // Net GST
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: isPayable ? PdfColors.red50 : PdfColors.green50,
              border: pw.Border.all(
                  color: isPayable ? PdfColors.red200 : PdfColors.green200),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    isPayable
                        ? 'Net GST payable to ATO'
                        : 'Net GST refundable from ATO',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: isPayable
                          ? PdfColors.red700
                          : PdfColors.green700,
                    ),
                  ),
                ),
                pw.Text(
                  isPayable
                      ? Formatters.formatCents(netGst)
                      : '(${Formatters.formatCents(netGst.abs())})',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color:
                        isPayable ? PdfColors.red700 : PdfColors.green700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Note
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Note: ',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600)),
              pw.Expanded(
                child: pw.Text(
                  'W1 (gross wages), W2 (PAYG withholding) and T7 (PAYG instalments) '
                  'are not recorded in this system.',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          ),

          pw.Spacer(),

          // Footer
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Period: $_periodLabel - '
                '${txns.length} transaction${txns.length == 1 ? '' : 's'}',
                style:
                    pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
              ),
              pw.Text('Generated $generated',
                  style: pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey400)),
            ],
          ),
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Widget _basPdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _basPdfRow(
      String code, String label, String hint, int cents,
      {required bool highlight}) {
    return pw.Column(
      children: [
        pw.Container(
          color: highlight ? PdfColors.blue50 : null,
          child: pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 36,
                  child: pw.Text(code,
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(label,
                          style: pw.TextStyle(fontSize: 9)),
                      pw.Text(hint,
                          style: pw.TextStyle(
                              fontSize: 7, color: PdfColors.grey500)),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 120,
                  child: pw.Text(
                    Formatters.formatCents(cents),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: highlight ? pw.FontWeight.bold : null,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Divider(thickness: 0.3, color: PdfColors.grey300),
      ],
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
        Text('BAS Report', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _loading ? null : _prevQuarter,
          tooltip: 'Previous quarter',
        ),
        Text(
          'Q$_quarter $_year',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: (!_loading && _canGoForward) ? _nextQuarter : null,
          tooltip: 'Next quarter',
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
          Text(_loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final txns = _quarterTransactions;
    final g1 = _computeG1(txns);
    final oneA = _compute1A(txns);
    final oneB = _compute1B(txns);
    final netGst = oneA - oneB;
    final isPayable = netGst >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIdentityCard(),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'GST on Sales',
          rows: [
            _BasRow(
              code: 'G1',
              label: 'Total sales',
              hint: 'All income for the quarter',
              cents: g1,
              onTap: () => _showBreakdown(
                  'G1', 'Total sales', _g1Transactions(txns),
                  useGst: false),
            ),
            _BasRow(
              code: '1A',
              label: 'GST on sales',
              hint: 'GST collected on GST-applicable income',
              cents: oneA,
              highlighted: true,
              onTap: () => _showBreakdown(
                  '1A', 'GST on sales', _oneATransactions(txns),
                  useGst: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'GST on Purchases',
          rows: [
            _BasRow(
              code: '1B',
              label: 'GST on purchases',
              hint: 'GST paid on GST-applicable expenses',
              cents: oneB,
              highlighted: true,
              onTap: () => _showBreakdown(
                  '1B', 'GST on purchases', _oneBTransactions(txns),
                  useGst: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNetCard(netGst, isPayable),
        const SizedBox(height: 16),
        _buildPayrollNote(),
        const SizedBox(height: 8),
        Text(
          'Period: $_periodLabel - ${txns.length} transaction${txns.length == 1 ? "" : "s"}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black45),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildIdentityCard() {
    final e = _entityDetails;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Q$_quarter $_year - ${_quarterMonthNames[_quarter]}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (e != null) ...[
                  Text(e.name,
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    "ABN ${Formatters.formatAbn(e.abn)} | ${e.incorporationIdentifier}",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ] else
                  Text(
                    "Entity details not configured - visit Admin > Entity",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange.shade700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<_BasRow> rows,
  }) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    const codeWidth = 48.0;
    const amountWidth = 160.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Divider(height: 1),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  SizedBox(width: codeWidth, child: Text('Field', style: labelStyle)),
                  Expanded(child: Text('Description', style: labelStyle)),
                  SizedBox(
                      width: amountWidth,
                      child: Text('Amount',
                          style: labelStyle, textAlign: TextAlign.right)),
                ],
              ),
            ),
            const Divider(height: 1),
            ...rows.map((r) => _buildBasRow(r, codeWidth, amountWidth)),
          ],
        ),
      ),
    );
  }

  Widget _buildBasRow(_BasRow row, double codeWidth, double amountWidth) {
    return Column(
      children: [
        Material(
          color: row.highlighted
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(60)
              : Colors.transparent,
          child: InkWell(
            onTap: row.onTap,
            child: Tooltip(
              message: 'Show the transactions that make up ${row.code}',
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: codeWidth,
                      child: Text(
                        row.code,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.label,
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (row.hint != null)
                            Text(
                              row.hint!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.black45),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: amountWidth,
                      child: Text(
                        Formatters.formatCents(row.cents),
                        style: TextStyle(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: row.highlighted ? FontWeight.bold : null,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: row.onTap == null
                            ? Colors.transparent
                            : Colors.black38),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Shows the transactions that make up a BAS field. [useGst] selects the
  /// GST component (1A/1B) rather than the GST-inclusive total (G1).
  void _showBreakdown(
    String code,
    String label,
    List<TransactionEntry> records, {
    required bool useGst,
  }) {
    final sorted = [...records]..sort((a, b) {
        final byDate = a.transactionDate.compareTo(b.transactionDate);
        return byDate != 0
            ? byDate
            : a.receiptNumber.compareTo(b.receiptNumber);
      });
    final int total =
        sorted.fold(0, (s, t) => s + (useGst ? t.gstAmount : t.totalAmount));

    showDialog<void>(
      context: context,
      builder: (ctx) => _BasBreakdownDialog(
        title: '$code — $label',
        subtitle: 'Q$_quarter $_year · $_periodLabel',
        amountHeading: useGst ? 'GST' : 'Total (inc GST)',
        total: total,
        rows: [
          for (final t in sorted)
            _BreakdownLine(
              date: t.transactionDate,
              receiptNumber: t.receiptNumber,
              contact: _contactMap[t.contactId]?.name ?? '',
              glAccount: _glMap.containsKey(t.generalLedgerId)
                  ? buildGlPath(_glEntries, t.generalLedgerId)
                  : '',
              description: t.description,
              cents: useGst ? t.gstAmount : t.totalAmount,
            ),
        ],
      ),
    );
  }

  Widget _buildNetCard(int netGst, bool isPayable) {
    final color = isPayable ? Colors.red.shade700 : Colors.green.shade700;
    final label =
        isPayable ? 'Net GST payable to ATO' : 'Net GST refundable from ATO';
    final amount = isPayable
        ? Formatters.formatCents(netGst)
        : '(${Formatters.formatCents(netGst.abs())})';

    return Card(
      elevation: 0,
      color: isPayable
          ? Colors.red.shade50
          : Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isPayable ? Colors.red.shade200 : Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              isPayable ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color),
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollNote() {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 14, color: Colors.black38),
        const SizedBox(width: 6),
        Text(
          'W1 (gross wages), W2 (PAYG withholding) and T7 (PAYG instalments) '
          'are not recorded in this system.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black45),
        ),
      ],
    );
  }
}

class _BasRow {
  final String code;
  final String label;
  final String? hint;
  final int cents;
  final bool highlighted;
  final VoidCallback? onTap;

  const _BasRow({
    required this.code,
    required this.label,
    this.hint,
    required this.cents,
    this.highlighted = false,
    this.onTap,
  });
}

/// One transaction line in a BAS field breakdown.
class _BreakdownLine {
  final String date;
  final String receiptNumber;
  final String contact;
  final String glAccount;
  final String description;
  final int cents;

  const _BreakdownLine({
    required this.date,
    required this.receiptNumber,
    required this.contact,
    required this.glAccount,
    required this.description,
    required this.cents,
  });
}

/// Dialog listing the transactions that make up a BAS field, with a total
/// that matches the figure on the report.
class _BasBreakdownDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amountHeading;
  final int total;
  final List<_BreakdownLine> rows;

  const _BasBreakdownDialog({
    required this.title,
    required this.subtitle,
    required this.amountHeading,
    required this.total,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? headStyle = textTheme.labelLarge;
    const TextStyle amountStyle =
        TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    final Size screen = MediaQuery.sizeOf(context);

    Widget line({
      required Widget date,
      required Widget receipt,
      required Widget contact,
      required Widget gl,
      required Widget description,
      required Widget amount,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: date),
            SizedBox(width: 100, child: receipt),
            Expanded(flex: 3, child: contact),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: gl),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: description),
            SizedBox(width: 120, child: amount),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(subtitle,
              style: textTheme.bodySmall?.copyWith(color: Colors.black54)),
        ],
      ),
      content: SizedBox(
        width: screen.width * 0.8 > 1100 ? 1100 : screen.width * 0.8,
        height: screen.height * 0.6,
        child: rows.isEmpty
            ? const Center(child: Text('No transactions this quarter.'))
            : Column(
                children: [
                  line(
                    date: Text('Date', style: headStyle),
                    receipt: Text('Receipt', style: headStyle),
                    contact: Text('Contact', style: headStyle),
                    gl: Text('GL account', style: headStyle),
                    description: Text('Description', style: headStyle),
                    amount: Text(amountHeading,
                        style: headStyle, textAlign: TextAlign.right),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SelectionArea(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final _BreakdownLine r = rows[i];
                          return line(
                            date: Text(r.date),
                            receipt: Text(r.receiptNumber),
                            contact: Text(r.contact),
                            gl: Text(r.glAccount),
                            description: Text(r.description),
                            amount: Text(Formatters.formatCents(r.cents),
                                style: amountStyle, textAlign: TextAlign.right),
                          );
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1.5),
                  line(
                    date: Text(
                        '${rows.length} transaction${rows.length == 1 ? '' : 's'}',
                        style: headStyle),
                    receipt: const SizedBox.shrink(),
                    contact: const SizedBox.shrink(),
                    gl: const SizedBox.shrink(),
                    description: Text('Total',
                        style: headStyle, textAlign: TextAlign.right),
                    amount: Text(Formatters.formatCents(total),
                        style:
                            amountStyle.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
