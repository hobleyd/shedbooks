import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bank_import_entry.dart';
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../utils/cba_receipt_parser.dart';
import '../utils/receipt_format.dart';
import '../widgets/bank_match_widgets.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class _CbaRow {
  final String processDate; // YYYY-MM-DD
  final String description;
  final bool isBankDebit; // true = money left the account
  final int amountCents;

  List<String> parsedReceipts;
  BankMatchStatus status = BankMatchStatus.unmatched;
  List<TransactionEntry> matched = const [];

  _CbaRow({
    required this.processDate,
    required this.description,
    required this.isBankDebit,
    required this.amountCents,
    this.parsedReceipts = const [],
  });

  bool get needsAction => status.needsAction;

  bool get isResolved =>
      status == BankMatchStatus.autoMatched ||
      status == BankMatchStatus.manuallyMatched ||
      status == BankMatchStatus.newTransaction;
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-page screen for importing and reconciling a CBA bank statement CSV.
class ImportCbaScreen extends StatefulWidget {
  const ImportCbaScreen({super.key});

  @override
  State<ImportCbaScreen> createState() => _ImportCbaScreenState();
}

class _ImportCbaScreenState extends State<ImportCbaScreen> {
  bool _loading = true;
  String? _loadError;

  List<TransactionEntry> _allTransactions = [];
  List<ContactEntry> _contacts = [];
  List<GeneralLedgerEntry> _glEntries = [];
  Map<String, String> _contactNames = {}; // contactId → display name

  ReceiptFormat _moneyInFormat = const ReceiptFormat('');
  ReceiptFormat _moneyOutFormat = const ReceiptFormat('');

  /// Dedup keys for rows already recorded in a previous import session.
  Set<String> _importedKeys = {};

  bool _fileParsed = false;
  String _fileName = '';
  List<_CbaRow> _rows = [];

  /// Transaction IDs already matched during this import session.
  final Set<String> _reservedIds = {};

  bool _saving = false;

  // ── Data loading ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Load after first frame so context is available for Provider.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();

      final txRes = await client.get('/transactions');
      if (txRes.statusCode != 200) {
        throw Exception('Failed to load transactions (${txRes.statusCode})');
      }
      final txList = jsonDecode(txRes.body) as List<dynamic>;
      _allTransactions = txList
          .map((j) => TransactionEntry.fromJson(j as Map<String, dynamic>))
          .toList();

      final ctRes = await client.get('/contacts');
      if (ctRes.statusCode != 200) {
        throw Exception('Failed to load contacts (${ctRes.statusCode})');
      }
      final ctList = jsonDecode(ctRes.body) as List<dynamic>;
      _contacts = ctList
          .map((j) => ContactEntry.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _contactNames = {for (final c in _contacts) c.id: c.name};

      final glRes = await client.get('/general-ledger');
      if (glRes.statusCode != 200) {
        throw Exception('Failed to load GL accounts (${glRes.statusCode})');
      }
      final glList = jsonDecode(glRes.body) as List<dynamic>;
      _glEntries = glList
          .map((j) => GeneralLedgerEntry.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      final entityRes = await client.get('/entity-details');
      if (entityRes.statusCode == 200) {
        final details = EntityDetails.fromJson(
            jsonDecode(entityRes.body) as Map<String, dynamic>);
        _moneyInFormat = ReceiptFormat(details.moneyInReceiptFormat);
        _moneyOutFormat = ReceiptFormat(details.moneyOutReceiptFormat);
      }
      // 404 means not yet configured — formats stay empty (no receipt parsing).

      final importRes = await client.get('/bank-imports');
      if (importRes.statusCode == 200) {
        final list = jsonDecode(importRes.body) as List<dynamic>;
        _importedKeys = list
            .map((j) => BankImportEntry.fromJson(j as Map<String, dynamic>)
                .dedupKey)
            .toSet();
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── File picking & parsing ───────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final content = utf8.decode(bytes);
    _parseAndMatch(content, file.name);
  }

  void _parseAndMatch(String content, String fileName) {
    final rows = _parseCsvContent(content);
    _reservedIds.clear();
    for (final row in rows) {
      if (!_isUserResolved(row.status)) _matchRow(row);
    }
    setState(() {
      _fileName = fileName;
      _rows = rows;
      _fileParsed = true;
    });
  }

  List<_CbaRow> _parseCsvContent(String content) {
    final lines =
        content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.isEmpty) return [];

    final header = _parseCsvLine(lines[0]);
    final trimmed = header.map((h) => h.trim().toLowerCase()).toList();

    int dateIdx = trimmed.indexWhere((h) => h.contains('date'));
    int descIdx = trimmed.indexWhere((h) => h == 'description');
    int debitIdx = trimmed.indexWhere((h) => h == 'debit');
    int creditIdx = trimmed.indexWhere((h) => h == 'credit');

    if (dateIdx < 0) dateIdx = 0;
    if (descIdx < 0) descIdx = 1;
    if (debitIdx < 0) debitIdx = 3;
    if (creditIdx < 0) creditIdx = 4;

    final rows = <_CbaRow>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.length < 5) continue;

      String safe(int idx) => idx < fields.length ? fields[idx].trim() : '';

      final dateStr = safe(dateIdx);
      final desc = safe(descIdx);
      final debitStr = safe(debitIdx);
      final creditStr = safe(creditIdx);

      final date = _parseCbaDate(dateStr);
      if (date.isEmpty) continue;

      final debitCents = debitStr.isNotEmpty ? _parseCents(debitStr) : null;
      final creditCents = creditStr.isNotEmpty ? _parseCents(creditStr) : null;

      if ((debitCents ?? 0) == 0 && (creditCents ?? 0) == 0) continue;

      final isDebit = debitCents != null && debitCents > 0;
      final now = DateTime.now();
      final List<String> receipts;
      if (isDebit) {
        receipts = parseCbaReceiptNumbers(desc, _moneyOutFormat, at: now);
      } else {
        receipts = parseCbaReceiptNumbers(desc, _moneyInFormat, at: now);
      }

      final row = _CbaRow(
        processDate: date,
        description: desc,
        isBankDebit: isDebit,
        amountCents: isDebit ? debitCents : (creditCents ?? 0),
        parsedReceipts: receipts,
      );
      final key = BankImportEntry(
        processDate: date,
        description: desc,
        amountCents: row.amountCents,
        isDebit: isDebit,
      ).dedupKey;
      if (_importedKeys.contains(key)) {
        row.status = BankMatchStatus.alreadyImported;
      }
      rows.add(row);
    }
    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    int i = 0;
    while (i < line.length) {
      if (line[i] == '"') {
        i++;
        final sb = StringBuffer();
        while (i < line.length && line[i] != '"') {
          sb.write(line[i]);
          i++;
        }
        if (i < line.length) i++; // skip closing quote
        fields.add(sb.toString());
        if (i < line.length && line[i] == ',') i++;
      } else {
        final start = i;
        while (i < line.length && line[i] != ',') i++;
        fields.add(line.substring(start, i).trim());
        if (i < line.length) i++;
      }
    }
    return fields;
  }

  // ── Matching logic ────────────────────────────────────────────────────────────

  void _matchRow(_CbaRow row) {
    if (row.isBankDebit) {
      _matchDebitRow(row);
    } else {
      _matchCreditRow(row);
    }
    for (final t in row.matched) _reservedIds.add(t.id);
  }

  void _matchDebitRow(_CbaRow row) {
    if (row.parsedReceipts.isNotEmpty) {
      final found = _allTransactions
          .where((t) =>
              !t.bankMatched &&
              !_reservedIds.contains(t.id) &&
              t.transactionType == 'debit' &&
              row.parsedReceipts.contains(t.receiptNumber))
          .toList();

      if (found.isEmpty) {
        final alreadyMatched = _allTransactions.any((t) =>
            t.bankMatched &&
            t.transactionType == 'debit' &&
            row.parsedReceipts.contains(t.receiptNumber));
        row.status =
            alreadyMatched ? BankMatchStatus.alreadyImported : BankMatchStatus.unmatched;
        row.matched = [];
        return;
      }

      final subset = findMatchingSubset(found, row.amountCents);
      row.matched = subset ?? found;
      row.status = subset != null
          ? BankMatchStatus.autoMatched
          : BankMatchStatus.amountMismatch;
      return;
    }

    // No P-numbers — fall back to date + amount.
    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            !_reservedIds.contains(t.id) &&
            t.transactionType == 'debit' &&
            t.transactionDate == row.processDate &&
            t.totalAmount == row.amountCents)
        .toList();

    if (candidates.length == 1) {
      row.status = BankMatchStatus.autoMatched;
      row.matched = candidates;
    } else if (candidates.length > 1) {
      row.status = BankMatchStatus.needsSelection;
      row.matched = candidates;
    } else {
      final alreadyMatched = _allTransactions.any((t) =>
          t.bankMatched &&
          t.transactionType == 'debit' &&
          t.transactionDate == row.processDate &&
          t.totalAmount == row.amountCents);
      row.status =
          alreadyMatched ? BankMatchStatus.alreadyImported : BankMatchStatus.unmatched;
      row.matched = [];
    }
  }

  void _matchCreditRow(_CbaRow row) {
    if (row.parsedReceipts.isNotEmpty) {
      final found = _allTransactions
          .where((t) =>
              !t.bankMatched &&
              !_reservedIds.contains(t.id) &&
              t.transactionType == 'credit' &&
              row.parsedReceipts.contains(t.receiptNumber))
          .toList();

      if (found.isNotEmpty) {
        final subset = findMatchingSubset(found, row.amountCents);
        row.matched = subset ?? found;
        row.status = subset != null
            ? BankMatchStatus.autoMatched
            : BankMatchStatus.amountMismatch;
        return;
      }

      // No un-matched transaction for receipt — check if already bank-matched.
      final alreadyMatchedByReceipt = _allTransactions.any((t) =>
          t.bankMatched &&
          t.transactionType == 'credit' &&
          row.parsedReceipts.contains(t.receiptNumber));
      if (alreadyMatchedByReceipt) {
        row.status = BankMatchStatus.alreadyImported;
        row.matched = [];
        return;
      }
    }

    // No receipt match — fall back to date + amount.
    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            !_reservedIds.contains(t.id) &&
            t.transactionType == 'credit' &&
            t.transactionDate == row.processDate &&
            t.totalAmount == row.amountCents)
        .toList();

    if (candidates.length == 1) {
      row.status = BankMatchStatus.autoMatched;
      row.matched = candidates;
    } else if (candidates.length > 1) {
      row.status = BankMatchStatus.needsSelection;
      row.matched = candidates;
    } else {
      final alreadyMatched = _allTransactions.any((t) =>
          t.bankMatched &&
          t.transactionType == 'credit' &&
          t.transactionDate == row.processDate &&
          t.totalAmount == row.amountCents);
      row.status =
          alreadyMatched ? BankMatchStatus.alreadyImported : BankMatchStatus.unmatched;
      row.matched = [];
    }
  }

  void _recomputeFrom(int index) {
    for (int i = index; i < _rows.length; i++) {
      if (!_isUserResolved(_rows[i].status)) {
        for (final t in _rows[i].matched) _reservedIds.remove(t.id);
      }
    }
    for (int i = index; i < _rows.length; i++) {
      if (!_isUserResolved(_rows[i].status)) {
        _matchRow(_rows[i]);
      }
    }
  }

  static bool _isUserResolved(BankMatchStatus s) =>
      s == BankMatchStatus.manuallyMatched ||
      s == BankMatchStatus.newTransaction ||
      s == BankMatchStatus.skipped ||
      s == BankMatchStatus.alreadyImported;

  // ── Manual matching dialog ────────────────────────────────────────────────────

  Future<void> _openManualMatch(_CbaRow row) async {
    final rowIndex = _rows.indexOf(row);

    // Release this row's current matches so they appear as selectable.
    for (final t in row.matched) _reservedIds.remove(t.id);

    final String type = row.isBankDebit ? 'debit' : 'credit';
    final month = _yearMonth(row.processDate);
    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            !_reservedIds.contains(t.id) &&
            t.transactionType == type &&
            _yearMonth(t.transactionDate) == month)
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final result = await showDialog<List<TransactionEntry>>(
      context: context,
      builder: (ctx) => ManualMatchDialog(
        description: row.description,
        processDate: row.processDate,
        bankAmountCents: row.amountCents,
        candidates: candidates,
        contactNames: _contactNames,
        initialSelection: Set<String>.from(row.matched.map((t) => t.id)),
      ),
    );

    if (result == null) {
      // Cancelled — restore.
      for (final t in row.matched) _reservedIds.add(t.id);
      return;
    }

    setState(() {
      for (final t in result) _reservedIds.add(t.id);
      row.matched = result;
      row.status = result.isEmpty
          ? BankMatchStatus.unmatched
          : BankMatchStatus.manuallyMatched;
      _recomputeFrom(rowIndex + 1);
    });
  }

  // ── Create new transaction ───────────────────────────────────────────────────

  Future<void> _openCreateTransaction(_CbaRow row) async {
    final rowIndex = _rows.indexOf(row);

    final result = await showDialog<TransactionEntry>(
      context: context,
      builder: (ctx) => _CreateTransactionDialog(
        row: row,
        contacts: _contacts,
        glEntries: _glEntries,
        api: context.read<ApiClient>(),
      ),
    );

    if (result == null) return;

    setState(() {
      // Release any previous match on this row.
      for (final t in row.matched) _reservedIds.remove(t.id);
      // Register the new transaction.
      _allTransactions.add(result);
      _reservedIds.add(result.id);
      row.matched = [result];
      row.status = BankMatchStatus.newTransaction;
      _recomputeFrom(rowIndex + 1);
    });
  }

  // ── Skip ──────────────────────────────────────────────────────────────────────

  void _toggleSkip(_CbaRow row) {
    final rowIndex = _rows.indexOf(row);
    setState(() {
      if (row.status == BankMatchStatus.skipped) {
        row.status = BankMatchStatus.unmatched;
        row.matched = [];
        _recomputeFrom(rowIndex);
      } else {
        for (final t in row.matched) _reservedIds.remove(t.id);
        row.matched = [];
        row.status = BankMatchStatus.skipped;
        _recomputeFrom(rowIndex + 1);
      }
    });
  }

  // ── Confirm ───────────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    final ids = _rows
        .where((r) => r.isResolved)
        .expand((r) => r.matched.map((t) => t.id))
        .toSet()
        .toList();

    if (ids.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _saving = true);

    try {
      final client = context.read<ApiClient>();

      final matchRes = await client.post(
        '/transactions/bank-match',
        jsonEncode({'transactionIds': ids}),
      );
      if (matchRes.statusCode != 204) {
        throw Exception('Server returned ${matchRes.statusCode}');
      }

      // Record every actioned row so re-imports skip them.
      final rowsToRecord = _rows
          .where((r) =>
              r.status != BankMatchStatus.alreadyImported &&
              r.status != BankMatchStatus.unmatched &&
              r.status != BankMatchStatus.needsSelection &&
              r.status != BankMatchStatus.amountMismatch)
          .map((r) => {
                'processDate': r.processDate,
                'description': r.description,
                'amountCents': r.amountCents,
                'isDebit': r.isBankDebit,
              })
          .toList();

      if (rowsToRecord.isNotEmpty) {
        final importRes = await client.post(
          '/bank-imports',
          jsonEncode({'rows': rowsToRecord}),
        );
        if (importRes.statusCode != 204) {
          throw Exception(
              'Failed to record import rows (${importRes.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Returns the YYYY-MM prefix of a YYYY-MM-DD date string.
  static String _yearMonth(String date) => date.length >= 7 ? date.substring(0, 7) : date;

  static String _parseCbaDate(String s) {
    final parts = s.trim().split('/');
    if (parts.length != 3) return '';
    return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
  }

  static int? _parseCents(String s) {
    final cleaned = s.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final src = cleaned.startsWith('.') ? '0$cleaned' : cleaned;
    final value = double.tryParse(src);
    if (value == null) return null;
    return (value * 100).round();
  }

  // ── Computed ──────────────────────────────────────────────────────────────────

  int get _matchedCount => _rows.where((r) => r.isResolved).length;

  int get _unmatchedCount => _rows.where((r) => r.needsAction).length;

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CBA Transactions'),
        actions: [
          if (_fileParsed && !_saving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _matchedCount > 0 ? _confirm : null,
                child: Text('Confirm ($_matchedCount matched)'),
              ),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : !_fileParsed
                  ? _buildPickerPrompt()
                  : _buildImportTable(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: $_loadError'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPickerPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Select a CBA bank statement CSV file to begin.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Pick CSV File'),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryBar(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Amount'), numeric: true),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Matched To')),
                  DataColumn(label: Text('')),
                ],
                rows: _rows.map(_buildDataRow).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 16),
          const SizedBox(width: 6),
          Text(_fileName,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          SummaryIndicator(
            icon: Icons.check_circle_outline,
            label: '$_matchedCount matched',
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          if (_unmatchedCount > 0)
            SummaryIndicator(
              icon: Icons.warning_amber_outlined,
              label: '$_unmatchedCount need attention',
              color: Colors.orange,
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: _saving ? null : _pickFile,
            child: const Text('Change File'),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(_CbaRow row) {
    final color = row.isBankDebit ? Colors.red.shade700 : Colors.green.shade700;
    final amtText = row.isBankDebit
        ? '-${formatAmount(row.amountCents)}'
        : formatAmount(row.amountCents);

    return DataRow(cells: [
      DataCell(Text(row.processDate,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
      DataCell(ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(row.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13)),
      )),
      DataCell(Text(amtText,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500))),
      DataCell(MatchStatusBadge(status: row.status)),
      DataCell(ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: MatchedToCell(
          receipts: row.matched.map((t) => t.receiptNumber).toList(),
          matchedTotal: row.matched.fold(0, (int s, t) => s + t.totalAmount),
          bankAmount: row.amountCents,
          parsedReceipts: row.parsedReceipts,
        ),
      )),
      DataCell(_actionCell(row)),
    ]);
  }

  Widget _actionCell(_CbaRow row) {
    if (row.status == BankMatchStatus.alreadyImported) {
      return const SizedBox.shrink();
    }

    if (row.status == BankMatchStatus.skipped) {
      return TextButton(
        onPressed: () => _toggleSkip(row),
        child: const Text('Unskip'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: _saving ? null : () => _openManualMatch(row),
          child: Text(row.matched.isEmpty ? 'Select...' : 'Change...'),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          tooltip: 'Create new transaction',
          onPressed: _saving ? null : () => _openCreateTransaction(row),
          color: Colors.teal,
        ),
        IconButton(
          icon: const Icon(Icons.not_interested_outlined, size: 18),
          tooltip: 'Skip',
          onPressed: _saving ? null : () => _toggleSkip(row),
          color: Colors.grey,
        ),
      ],
    );
  }
}

// ── Create transaction dialog ─────────────────────────────────────────────────

class _CreateTransactionDialog extends StatefulWidget {
  final _CbaRow row;
  final List<ContactEntry> contacts;
  final List<GeneralLedgerEntry> glEntries;
  final ApiClient api;

  const _CreateTransactionDialog({
    required this.row,
    required this.contacts,
    required this.glEntries,
    required this.api,
  });

  @override
  State<_CreateTransactionDialog> createState() =>
      _CreateTransactionDialogState();
}

class _CreateTransactionDialogState extends State<_CreateTransactionDialog> {
  ContactEntry? _contact;
  GeneralLedgerEntry? _gl;

  late final TextEditingController _descController;
  late final TextEditingController _receiptController;
  late final TextEditingController _totalController;
  late final TextEditingController _gstController;
  late final TextEditingController _amountController;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final row = widget.row;

    _descController = TextEditingController(text: row.description);
    _receiptController = TextEditingController(
      text: row.parsedReceipts.length == 1 ? row.parsedReceipts.first : '',
    );
    _totalController = TextEditingController(
      text: _centsToField(row.amountCents),
    );
    _gstController = TextEditingController(text: '0.00');
    _amountController = TextEditingController(
      text: _centsToField(row.amountCents),
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    _receiptController.dispose();
    _totalController.dispose();
    _gstController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _centsToField(int cents) {
    final d = cents ~/ 100;
    final r = cents % 100;
    return '$d.${r.toString().padLeft(2, '0')}';
  }

  static int _fieldToCents(String s) {
    final v = double.tryParse(s.replaceAll(',', '')) ?? 0;
    return (v * 100).round();
  }

  /// Updates amount and GST fields based on the currently selected GL and
  /// the value in the total field.
  void _recalculate() {
    final totalCents = _fieldToCents(_totalController.text);
    if (_gl?.gstApplicable == true) {
      final gstCents = (totalCents / 11).round();
      final amtCents = totalCents - gstCents;
      _gstController.text = _centsToField(gstCents);
      _amountController.text = _centsToField(amtCents);
    } else {
      _gstController.text = '0.00';
      _amountController.text = _centsToField(totalCents);
    }
  }

  // ── GL selection ─────────────────────────────────────────────────────────────

  List<GeneralLedgerEntry> get _filteredGl {
    final wantDirection =
        widget.row.isBankDebit ? GlDirection.moneyOut : GlDirection.moneyIn;
    return widget.glEntries
        .where((g) => g.direction == wantDirection)
        .toList();
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_contact == null) {
      setState(() => _error = 'Please select a contact.');
      return;
    }
    if (_gl == null) {
      setState(() => _error = 'Please select a GL account.');
      return;
    }
    final receipt = _receiptController.text.trim();
    if (receipt.isEmpty) {
      setState(() => _error = 'Receipt number is required.');
      return;
    }

    final amountCents = _fieldToCents(_amountController.text);
    final gstCents = _fieldToCents(_gstController.text);
    if (amountCents <= 0) {
      setState(() => _error = 'Amount must be greater than zero.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final body = jsonEncode({
        'contactId': _contact!.id,
        'generalLedgerId': _gl!.id,
        'amount': amountCents,
        'gstAmount': gstCents,
        'transactionType': widget.row.isBankDebit ? 'debit' : 'credit',
        'receiptNumber': receipt,
        'description': _descController.text.trim(),
        'transactionDate': widget.row.processDate,
      });
      final res = await widget.api.post('/transactions', body);
      if (res.statusCode != 201) {
        final msg = (jsonDecode(res.body) as Map?)?['error'] ?? res.statusCode;
        throw Exception(msg);
      }
      final tx = TransactionEntry.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      if (mounted) Navigator.of(context).pop(tx);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.row.isBankDebit ? 'Debit (money out)' : 'Credit (money in)';

    return AlertDialog(
      title: const Text('Create Transaction'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bank row summary
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.row.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.row.processDate}  '
                      '${formatAmount(widget.row.amountCents)}  '
                      '$typeLabel',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date (read-only)
              _label('Date'),
              Text(widget.row.processDate,
                  style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 12),

              // Contact
              _label('Contact *'),
              _dropdown<ContactEntry>(
                value: _contact,
                hint: 'Select contact',
                items: widget.contacts,
                labelOf: (c) => c.name,
                onChanged: (v) => setState(() => _contact = v),
              ),
              const SizedBox(height: 12),

              // GL Account
              _label('GL Account *'),
              DropdownButton<GeneralLedgerEntry>(
                value: _gl,
                isExpanded: true,
                hint: const Text('Select account'),
                underline: const SizedBox.shrink(),
                items: _filteredGl.map((g) {
                  final isIn = g.direction == GlDirection.moneyIn;
                  return DropdownMenuItem<GeneralLedgerEntry>(
                    value: g,
                    child: Row(children: [
                      Icon(
                        isIn
                            ? Icons.arrow_circle_down_outlined
                            : Icons.arrow_circle_up_outlined,
                        size: 14,
                        color: isIn
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          g.description,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _gl = v;
                  _recalculate();
                }),
              ),
              const SizedBox(height: 12),

              // Receipt
              _label('Receipt Number *'),
              TextField(
                controller: _receiptController,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 12),

              // Description
              _label('Description'),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(isDense: true),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Amounts row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Total (incl. GST)'),
                        TextField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              isDense: true, prefixText: '\$'),
                          onChanged: (_) => setState(_recalculate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('GST'),
                        TextField(
                          controller: _gstController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              isDense: true, prefixText: '\$'),
                          onChanged: (_) {
                            setState(() {
                              final totalCents =
                                  _fieldToCents(_totalController.text);
                              final gstCents =
                                  _fieldToCents(_gstController.text);
                              _amountController.text =
                                  _centsToField(totalCents - gstCents);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Amount (excl. GST)'),
                        TextField(
                          controller: _amountController,
                          readOnly: true,
                          decoration: const InputDecoration(
                              isDense: true, prefixText: '\$'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButton<T>(
      value: value,
      isExpanded: true,
      hint: Text(hint),
      underline: const SizedBox.shrink(),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
