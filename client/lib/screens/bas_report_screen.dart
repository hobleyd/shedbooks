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
  EntityDetails? _entityDetails;

  late int _quarter;
  late int _year;

  static const _quarterMonthNames = {
    1: 'January – March',
    2: 'April – June',
    3: 'July – September',
    4: 'October – December',
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

  /// G1: Total sales — all credit (money-in) transaction totals.
  int _computeG1(List<TransactionEntry> txns) =>
      txns.where((t) => t.isCredit).fold(0, (s, t) => s + t.totalAmount);

  /// 1A: GST on sales — GST component of GST-applicable credit transactions.
  int _compute1A(List<TransactionEntry> txns) => txns
      .where((t) =>
          t.isCredit && (_glMap[t.generalLedgerId]?.gstApplicable ?? false))
      .fold(0, (s, t) => s + t.gstAmount);

  /// 1B: GST on purchases — GST component of GST-applicable debit transactions.
  int _compute1B(List<TransactionEntry> txns) => txns
      .where((t) =>
          !t.isCredit && (_glMap[t.generalLedgerId]?.gstApplicable ?? false))
      .fold(0, (s, t) => s + t.gstAmount);

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

  String _formatDateShort(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Future<void> _generatePdf() async {
    final txns = _quarterTransactions;
    final g1 = _computeG1(txns);
    final oneA = _compute1A(txns);
    final oneB = _compute1B(txns);
    final netGst = oneA - oneB;
    final isPayable = netGst >= 0;
    final entity = _entityDetails;
    final generated = _formatDateShort(DateTime.now());

    final doc = pw.Document(title: 'BAS Q$_quarter $_year');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(50),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Entity header
          if (entity != null) ...[
            pw.Text(entity.name,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(
              'ABN: ${_formatAbn(entity.abn)}  |  ${entity.incorporationIdentifier}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 14),
          ],
          pw.Text('Business Activity Statement',
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Q$_quarter $_year  —  ${_quarterMonthNames[_quarter]}',
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
                      ? _formatCents(netGst)
                      : '(${_formatCents(netGst.abs())})',
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
                'Period: $_periodLabel  ·  '
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
                    _formatCents(cents),
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
            ),
            _BasRow(
              code: '1A',
              label: 'GST on sales',
              hint: 'GST collected on GST-applicable income',
              cents: oneA,
              highlighted: true,
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
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNetCard(netGst, isPayable),
        const SizedBox(height: 16),
        _buildPayrollNote(),
        const SizedBox(height: 8),
        Text(
          'Period: $_periodLabel   ·   '
          '${txns.length} transaction${txns.length == 1 ? '' : 's'}',
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
                  'Q${_quarter} $_year  —  ${_quarterMonthNames[_quarter]}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (e != null) ...[
                  Text(e.name,
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    'ABN ${_formatAbn(e.abn)}  ·  ${e.incorporationIdentifier}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ] else
                  Text(
                    'Entity details not configured — visit Admin › Entity',
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
        Container(
          color: row.highlighted
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(60)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                    _formatCents(row.cents),
                    style: TextStyle(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: row.highlighted ? FontWeight.bold : null,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildNetCard(int netGst, bool isPayable) {
    final color = isPayable ? Colors.red.shade700 : Colors.green.shade700;
    final label =
        isPayable ? 'Net GST payable to ATO' : 'Net GST refundable from ATO';
    final amount = isPayable
        ? _formatCents(netGst)
        : '(${_formatCents(netGst.abs())})';

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
        Icon(Icons.info_outline, size: 14, color: Colors.black38),
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

  const _BasRow({
    required this.code,
    required this.label,
    this.hint,
    required this.cents,
    this.highlighted = false,
  });
}
