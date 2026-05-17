import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../auth/auth_state.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/pnl_data.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../widgets/pdf_report_components.dart';
import '../widgets/pnl_pdf_report.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthSummary {
  final int month;
  int incomeCents = 0;
  int outgoingsCents = 0;
  _MonthSummary(this.month);
  int get netCents => incomeCents - outgoingsCents;
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final TextEditingController _narrativeController = TextEditingController();
  EntityDetails? _entityDetails;
  List<TransactionEntry> _allTransactions = [];
  Map<String, GeneralLedgerEntry> _glMap = {};
  bool _loading = true;
  List<PlatformFile> _bankStatements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/entity-details'),
        client.get('/transactions'),
        client.get('/general-ledger'),
      ]);
      if (!mounted) return;

      if (results.any((r) => r.statusCode != 200)) {
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _entityDetails = EntityDetails.fromJson(
          jsonDecode(results[0].body) as Map<String, dynamic>,
        );
        _allTransactions = (jsonDecode(results[1].body) as List)
            .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        final glList = (jsonDecode(results[2].body) as List)
            .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _glMap = {for (final g in glList) g.id: g};
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

  @override
  void dispose() {
    _narrativeController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
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

    // Dashboard Data (Current Year Summary)
    final dashboardMonths = _buildMonthSummaries(_allTransactions, reportYear);

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
      margin: const pw.EdgeInsets.all(50),
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
                'Treasurer’s Financial Report – $reportMonthName $reportYear',
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
        pw.SizedBox(height: 32),

        // Narrative
        if (narrative.isNotEmpty) ...[
          pw.Text('Narrative', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(narrative, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 32),
        ],

        // Dashboard Summary Table
        pw.Text('Monthly Performance Summary ($reportYear)',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _buildDashboardTable(dashboardMonths, monthNames),
        pw.SizedBox(height: 32),
      ],
    ));

    // Append P&L on a separate page
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(50),
      header: (ctx) {
        if (ctx.pageNumber == 1) return pw.SizedBox(height: 0); // Not applicable for the second doc.addPage but good practice
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${entity?.name ?? ''}  —  Profit & Loss  —  $reportMonthName $reportYear (continued)',
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

    // Append Bank Statements
    for (final file in _bankStatements) {
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

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  List<_MonthSummary> _buildMonthSummaries(List<TransactionEntry> transactions, int year) {
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
    return summaries.values.toList();
  }

  pw.Widget _buildDashboardTable(List<_MonthSummary> months, List<String> monthNames) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeader('Month'),
            _tableHeader('Income'),
            _tableHeader('Outgoings'),
            _tableHeader('Net'),
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
              ],
            )),
      ],
    );
  }

  pw.Widget _tableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text,
            textAlign: align, style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black)),
      );

  @override
  Widget build(BuildContext context) {
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
                  'Treasurer’s Financial Report – $reportMonth $reportYear',
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
                ..._bankStatements.asMap().entries.map((e) => ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                      title: Text(e.value.name, style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeBankStatement(e.key),
                      ),
                    )),
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
