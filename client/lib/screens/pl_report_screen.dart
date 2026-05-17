import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/pnl_data.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../widgets/pdf_report_components.dart';
import '../widgets/pnl_pdf_report.dart';
import '../widgets/pnl_report_widget.dart';

enum _PeriodType { month, quarter, year }

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

  // ── Data filtering ──────────────────────────────────────────────

  bool _transactionFilter(TransactionEntry t) {
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
  }

  // ── PDF generation ─────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final data = PnLData.compute(
      allTransactions: _allTransactions,
      glMap: _glMap,
      filter: _transactionFilter,
    );
    final entity = _entityDetails;
    final generated = Formatters.formatDateShort(DateTime.now());

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
          data: data,
          periodEndedLabel: _periodEndedLabel,
          formatCents: Formatters.formatCents,
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
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
    final data = PnLData.compute(
      allTransactions: _allTransactions,
      glMap: _glMap,
      filter: _transactionFilter,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: PnlReportWidget(
        data: data,
        periodEndedLabel: _periodEndedLabel,
      ),
    );
  }
}
