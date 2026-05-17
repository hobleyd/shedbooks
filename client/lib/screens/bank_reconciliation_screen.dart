import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/bank_account_summary.dart';
import '../models/cba_statement_data.dart';
import '../models/contact_entry.dart';
import '../models/locked_month_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../utils/cba_receipt_parser.dart';
import '../utils/receipt_format.dart';
import '../models/entity_details.dart';
import '../widgets/bank_match_widgets.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _RecRow {
  final CbaTransactionEntry source;

  // Date as YYYY-MM-DD (matches source.date from server parser).
  final String processDate;

  List<String> parsedReceipts;
  BankMatchStatus status = BankMatchStatus.unmatched;
  List<TransactionEntry> matched = const [];

  _RecRow({
    required this.source,
    required this.processDate,
    this.parsedReceipts = const [],
  });

  bool get needsAction => status.needsAction;

  bool get isResolved =>
      status == BankMatchStatus.autoMatched ||
      status == BankMatchStatus.manuallyMatched;
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Phase { upload, results, matching }

class BankReconciliationScreen extends StatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  State<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  // Loaded reference data.
  bool _loading = true;
  String? _loadError;
  List<TransactionEntry> _allTransactions = [];
  Map<String, String> _contactNames = {};
  Set<String> _lockedMonths = {};
  ReceiptFormat _moneyInFormat = const ReceiptFormat('');
  ReceiptFormat _moneyOutFormat = const ReceiptFormat('');
  List<BankAccountSummary> _bankAccounts = [];

  // Bank account selection.
  String? _selectedBankAccountId;

  // PDF parse result.
  _Phase _phase = _Phase.upload;
  bool _parsing = false;
  String? _parseError;
  CbaStatementData? _statement;

  // Editable balance overrides (in cents, null = use parsed value).
  final _openingCtrl = TextEditingController();
  final _closingCtrl = TextEditingController();

  // Matching phase.
  List<_RecRow> _rows = [];
  final Set<String> _reservedIds = {};

  bool _locking = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    _closingCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/transactions'),
        client.get('/locked-months'),
        client.get('/entity-details'),
        client.get('/contacts'),
        client.get('/bank-reconciliation/bank-accounts'),
      ]);

      final txRes = results[0];
      if (txRes.statusCode != 200) {
        throw Exception('Failed to load transactions');
      }
      _allTransactions = (jsonDecode(txRes.body) as List<dynamic>)
          .map((j) => TransactionEntry.fromJson(j as Map<String, dynamic>))
          .toList();

      final lmRes = results[1];
      if (lmRes.statusCode == 200) {
        final list = jsonDecode(lmRes.body) as List<dynamic>;
        _lockedMonths = list
            .map((j) => LockedMonthEntry.fromJson(j as Map<String, dynamic>)
                .monthYear)
            .toSet();
      }

      final edRes = results[2];
      if (edRes.statusCode == 200) {
        final details = EntityDetails.fromJson(
            jsonDecode(edRes.body) as Map<String, dynamic>);
        _moneyInFormat = ReceiptFormat(details.moneyInReceiptFormat);
        _moneyOutFormat = ReceiptFormat(details.moneyOutReceiptFormat);
      }

      final ctRes = results[3];
      if (ctRes.statusCode == 200) {
        final list = jsonDecode(ctRes.body) as List<dynamic>;
        final contacts = list
            .map((j) => ContactEntry.fromJson(j as Map<String, dynamic>))
            .toList();
        _contactNames = {for (final c in contacts) c.id: c.name};
      }

      final baRes = results[4];
      if (baRes.statusCode == 200) {
        final list = jsonDecode(baRes.body) as List<dynamic>;
        _bankAccounts = list
            .map((j) =>
                BankAccountSummary.fromJson(j as Map<String, dynamic>))
            .toList();
        // Pre-select if only one bank account exists.
        if (_bankAccounts.length == 1 && _selectedBankAccountId == null) {
          _selectedBankAccountId = _bankAccounts.first.id;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── PDF upload & parse ───────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    if (_selectedBankAccountId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    setState(() {
      _parsing = true;
      _parseError = null;
    });

    try {
      final client = context.read<ApiClient>();
      final res = await client.postBytes(
          '/bank-reconciliation/parse-statement', bytes);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final stmt = CbaStatementData.fromJson(json);
        _statement = stmt;
        _openingCtrl.text = _centsToDisplay(stmt.openingBalanceCents);
        _closingCtrl.text = _centsToDisplay(stmt.closingBalanceCents);
        _phase = _Phase.results;
        _parseError = null;
      } else {
        final msg = (jsonDecode(res.body) as Map?)?['error']?.toString() ??
            'Parse failed (${res.statusCode})';
        _parseError = msg;
      }
    } catch (e) {
      _parseError = e.toString();
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  // ── Balance check & lock ─────────────────────────────────────────────────────

  String? _statementMonthYear() {
    final stmt = _statement;
    if (stmt == null) return null;
    final parts = stmt.statementPeriod.split(' - ');
    if (parts.isEmpty) return null;
    return _parsePeriodMonthYear(parts.last.trim());
  }

  String? _statementEndDate() {
    final stmt = _statement;
    if (stmt == null) return null;
    final parts = stmt.statementPeriod.split(' - ');
    if (parts.length < 2) return null;
    return _parsePeriodIsoDate(parts.last.trim());
  }

  String? _parsePeriodMonthYear(String dateStr) {
    // "30 Apr 2026" → "2026-04"
    const months = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
      'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
      'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
    };
    final parts = dateStr.trim().split(' ');
    if (parts.length < 3) return null;
    final m = months[parts[1]];
    if (m == null) return null;
    return '${parts[2]}-$m';
  }

  String? _parsePeriodIsoDate(String dateStr) {
    // "30 Apr 2026" → "2026-04-30"
    const months = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
      'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
      'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
    };
    final parts = dateStr.trim().split(' ');
    if (parts.length < 3) return null;
    final m = months[parts[1]];
    if (m == null) return null;
    return '${parts[2]}-$m-${parts[0].padLeft(2, '0')}';
  }

  bool get _monthAlreadyLocked {
    final my = _statementMonthYear();
    return my != null && _lockedMonths.contains(my);
  }

  int get _openingCents =>
      _parseCentsFromDisplay(_openingCtrl.text) ??
      (_statement?.openingBalanceCents ?? 0);

  int get _closingCents =>
      _parseCentsFromDisplay(_closingCtrl.text) ??
      (_statement?.closingBalanceCents ?? 0);

  List<TransactionEntry> _monthTransactions() {
    final my = _statementMonthYear();
    if (my == null) return [];
    return _allTransactions
        .where((t) => t.transactionDate.startsWith(my))
        .toList();
  }

  bool get _allMonthTransactionsMatched {
    final txs = _monthTransactions();
    return txs.isNotEmpty && txs.every((t) => t.bankMatched);
  }

  int _computedClosingCents() {
    final txs = _monthTransactions();
    int balance = _openingCents;
    for (final t in txs) {
      if (t.transactionType == 'debit') {
        balance -= t.totalAmount;
      } else {
        balance += t.totalAmount;
      }
    }
    return balance;
  }

  bool get _balancesMatch => _computedClosingCents() == _closingCents;

  String? get _selectedAccountName {
    if (_selectedBankAccountId == null) return null;
    try {
      return _bankAccounts
          .firstWhere((a) => a.id == _selectedBankAccountId)
          .accountName;
    } catch (_) {
      return null;
    }
  }

  Future<void> _lockMonth() async {
    final my = _statementMonthYear();
    final endDate = _statementEndDate();
    if (my == null || endDate == null) return;

    if (_selectedBankAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a bank account before locking the month.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock month?'),
        content: Text(
          'Lock $my? No further transactions will be editable in this period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _locking = true);
    try {
      final client = context.read<ApiClient>();

      // Save closing balance and lock month concurrently.
      final results = await Future.wait([
        client.post(
          '/closing-bank-balances',
          jsonEncode({
            'bankAccountId': _selectedBankAccountId,
            'balanceDate': endDate,
            'balanceCents': _closingCents,
            'statementPeriod': _statement!.statementPeriod,
          }),
        ),
        client.post('/locked-months', jsonEncode({'monthYear': my})),
      ]);

      final balanceRes = results[0];
      if (balanceRes.statusCode != 201) {
        final msg =
            (jsonDecode(balanceRes.body) as Map?)?['error'] ?? balanceRes.statusCode;
        throw Exception('Failed to save closing balance: $msg');
      }

      final lockRes = results[1];
      if (lockRes.statusCode != 204) {
        final msg =
            (jsonDecode(lockRes.body) as Map?)?['error'] ?? lockRes.statusCode;
        throw Exception('Failed to lock month: $msg');
      }

      _lockedMonths = {..._lockedMonths, my};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$my has been locked.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/transactions');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to lock: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locking = false);
    }
  }

  // ── Matching phase ────────────────────────────────────────────────────────────

  void _enterMatchingPhase() {
    final stmt = _statement;
    if (stmt == null) return;

    final now = DateTime.now();
    _rows = stmt.transactions.map((tx) {
      final date = tx.date;
      final desc = tx.description;
      final List<String> receipts;
      if (tx.isDebit) {
        receipts = parseCbaReceiptNumbers(desc, _moneyOutFormat, at: now);
      } else {
        receipts = parseCbaReceiptNumbers(desc, _moneyInFormat, at: now);
      }
      return _RecRow(
        source: tx,
        processDate: date,
        parsedReceipts: receipts,
      );
    }).toList();

    _reservedIds.clear();
    for (final row in _rows) {
      _matchRow(row);
    }

    setState(() => _phase = _Phase.matching);
  }

  void _matchRow(_RecRow row) {
    if (row.source.isDebit) {
      _matchDebitRow(row);
    } else {
      _matchCreditRow(row);
    }
    for (final t in row.matched) _reservedIds.add(t.id);
  }

  void _matchDebitRow(_RecRow row) {
    if (row.parsedReceipts.isNotEmpty) {
      final found = _allTransactions
          .where((t) =>
              !t.bankMatched &&
              !_reservedIds.contains(t.id) &&
              t.transactionType == 'debit' &&
              row.parsedReceipts.contains(t.receiptNumber))
          .toList();

      if (found.isEmpty) {
        final already = _allTransactions.any((t) =>
            t.bankMatched &&
            t.transactionType == 'debit' &&
            row.parsedReceipts.contains(t.receiptNumber));
        row.status = already
            ? BankMatchStatus.alreadyImported
            : BankMatchStatus.unmatched;
        row.matched = [];
        return;
      }

      final subset = findMatchingSubset(found, row.source.amountCents);
      row.matched = subset ?? found;
      row.status = subset != null
          ? BankMatchStatus.autoMatched
          : BankMatchStatus.amountMismatch;
      return;
    }

    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            !_reservedIds.contains(t.id) &&
            t.transactionType == 'debit' &&
            t.transactionDate == row.processDate &&
            t.totalAmount == row.source.amountCents)
        .toList();

    if (candidates.length == 1) {
      row.status = BankMatchStatus.autoMatched;
      row.matched = candidates;
    } else if (candidates.length > 1) {
      row.status = BankMatchStatus.needsSelection;
      row.matched = candidates;
    } else {
      final already = _allTransactions.any((t) =>
          t.bankMatched &&
          t.transactionType == 'debit' &&
          t.transactionDate == row.processDate &&
          t.totalAmount == row.source.amountCents);
      row.status = already
          ? BankMatchStatus.alreadyImported
          : BankMatchStatus.unmatched;
      row.matched = [];
    }
  }

  void _matchCreditRow(_RecRow row) {
    if (row.parsedReceipts.isNotEmpty) {
      final found = _allTransactions
          .where((t) =>
              !t.bankMatched &&
              !_reservedIds.contains(t.id) &&
              t.transactionType == 'credit' &&
              row.parsedReceipts.contains(t.receiptNumber))
          .toList();

      if (found.isNotEmpty) {
        final subset = findMatchingSubset(found, row.source.amountCents);
        row.matched = subset ?? found;
        row.status = subset != null
            ? BankMatchStatus.autoMatched
            : BankMatchStatus.amountMismatch;
        return;
      }

      final alreadyByReceipt = _allTransactions.any((t) =>
          t.bankMatched &&
          t.transactionType == 'credit' &&
          row.parsedReceipts.contains(t.receiptNumber));
      if (alreadyByReceipt) {
        row.status = BankMatchStatus.alreadyImported;
        row.matched = [];
        return;
      }
    }

    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            !_reservedIds.contains(t.id) &&
            t.transactionType == 'credit' &&
            t.transactionDate == row.processDate &&
            t.totalAmount == row.source.amountCents)
        .toList();

    if (candidates.length == 1) {
      row.status = BankMatchStatus.autoMatched;
      row.matched = candidates;
    } else if (candidates.length > 1) {
      row.status = BankMatchStatus.needsSelection;
      row.matched = candidates;
    } else {
      final already = _allTransactions.any((t) =>
          t.bankMatched &&
          t.transactionType == 'credit' &&
          t.transactionDate == row.processDate &&
          t.totalAmount == row.source.amountCents);
      row.status = already
          ? BankMatchStatus.alreadyImported
          : BankMatchStatus.unmatched;
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
      s == BankMatchStatus.skipped ||
      s == BankMatchStatus.alreadyImported;

  void _toggleSkip(_RecRow row) {
    final idx = _rows.indexOf(row);
    if (idx < 0) return;
    setState(() {
      if (row.status == BankMatchStatus.skipped) {
        row.status = BankMatchStatus.unmatched;
        row.matched = [];
        _recomputeFrom(idx);
      } else {
        for (final t in row.matched) _reservedIds.remove(t.id);
        row.matched = [];
        row.status = BankMatchStatus.skipped;
        _recomputeFrom(idx + 1);
      }
    });
  }

  Future<void> _openManualMatch(_RecRow row) async {
    final rowIndex = _rows.indexOf(row);
    if (rowIndex < 0) return;

    // Release this row's current matches so they appear as selectable.
    for (final t in row.matched) _reservedIds.remove(t.id);

    final type = row.source.isDebit ? 'debit' : 'credit';
    final month = _yearMonth(row.processDate);
    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            !_reservedIds.contains(t.id) &&
            t.transactionType == type &&
            _yearMonth(t.transactionDate) == month)
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    if (!mounted) return;
    final result = await showDialog<List<TransactionEntry>>(
      context: context,
      builder: (ctx) => ManualMatchDialog(
        description: row.source.description,
        processDate: row.processDate,
        bankAmountCents: row.source.amountCents,
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

  bool get _allRowsResolved => _rows.every((r) => !r.needsAction);

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
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

    // The matching phase fills the viewport without outer padding.
    if (_phase == _Phase.matching) {
      return _buildMatching();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: _phase == _Phase.upload ? _buildUpload() : _buildResults(),
    );
  }

  // ── Upload phase ──────────────────────────────────────────────────────────────

  Widget _buildUpload() {
    final noBankAccounts = _bankAccounts.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bank Reconciliation',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Upload a CBA bank statement PDF to reconcile transactions for the month.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 32),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Select bank account',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    if (noBankAccounts)
                      Text(
                        'No bank accounts configured. Add one in Admin → Bank Accounts.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.error),
                      )
                    else
                      _buildBankAccountDropdown(),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    Center(
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text('Select a CBA bank statement PDF',
                          style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                    if (_parseError != null) ...[
                      Text(
                        _parseError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: FilledButton.icon(
                        onPressed: (_parsing ||
                                noBankAccounts ||
                                _selectedBankAccountId == null)
                            ? null
                            : _pickPdf,
                        icon: _parsing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(_parsing ? 'Parsing…' : 'Choose PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankAccountDropdown() {
    return DropdownButton<String>(
      value: _selectedBankAccountId,
      isExpanded: true,
      hint: const Text('Select account…'),
      items: _bankAccounts
          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.accountName)))
          .toList(),
      onChanged: (id) => setState(() => _selectedBankAccountId = id),
    );
  }

  // ── Results phase ─────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final stmt = _statement!;
    final monthYear = _statementMonthYear();
    final allMatched = _allMonthTransactionsMatched;
    final balanced = _balancesMatch;
    final alreadyLocked = _monthAlreadyLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Bank Reconciliation',
                style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() {
                _phase = _Phase.upload;
                _statement = null;
                _parseError = null;
              }),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Choose different file'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statement Details',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _detailRow('Account', stmt.accountNumber),
                  _detailRow('Period', stmt.statementPeriod),
                  _bankAccountRow(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _balanceField(
                          label: 'Opening Balance',
                          controller: _openingCtrl,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _balanceField(
                          label: 'Closing Balance',
                          controller: _closingCtrl,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildReconcileStatus(
            monthYear: monthYear,
            allMatched: allMatched,
            balanced: balanced,
            alreadyLocked: alreadyLocked,
          ),
        ),
      ],
    );
  }

  Widget _bankAccountRow() {
    final name = _selectedAccountName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text('Bank Account',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          if (name != null)
            Text(name, style: const TextStyle(fontSize: 13))
          else
            Text('Not selected',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.error,
                    fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _balanceField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: '\$ ',
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildReconcileStatus({
    required String? monthYear,
    required bool allMatched,
    required bool balanced,
    required bool alreadyLocked,
  }) {
    final txs = _monthTransactions();

    if (alreadyLocked) {
      return _statusCard(
        icon: Icons.lock,
        color: Colors.orange,
        title: 'Month already locked',
        message: '$monthYear is already locked. No further action required.',
      );
    }

    if (txs.isEmpty) {
      return _statusCard(
        icon: Icons.info_outline,
        color: Colors.blue,
        title: 'No transactions found',
        message: monthYear != null
            ? 'No transactions exist in the system for $monthYear.'
            : 'Could not determine statement month.',
        trailing: TextButton.icon(
          onPressed: _enterMatchingPhase,
          icon: const Icon(Icons.compare_arrows_outlined, size: 16),
          label: const Text('Match transactions from PDF'),
        ),
      );
    }

    final unmatchedCount = txs.where((t) => !t.bankMatched).length;

    if (!allMatched) {
      return _statusCard(
        icon: Icons.warning_amber_outlined,
        color: Colors.orange,
        title:
            '$unmatchedCount transaction${unmatchedCount == 1 ? '' : 's'} not bank-matched',
        message: 'Not all transactions for $monthYear have been bank-matched. '
            'Match them using the PDF statement data below.',
        trailing: FilledButton.icon(
          onPressed: _enterMatchingPhase,
          icon: const Icon(Icons.compare_arrows_outlined, size: 16),
          label: const Text('Match transactions'),
        ),
      );
    }

    if (!balanced) {
      final computed = _computedClosingCents();
      return _statusCard(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Balance mismatch',
        message: 'All transactions are matched, but the computed closing balance '
            '(${_centsToDisplay(computed)}) does not match the stated closing '
            'balance (${_centsToDisplay(_closingCents)}).\n\n'
            'Check the opening/closing balance figures or match transactions from the PDF.',
        trailing: TextButton.icon(
          onPressed: _enterMatchingPhase,
          icon: const Icon(Icons.compare_arrows_outlined, size: 16),
          label: const Text('Review PDF transactions'),
        ),
      );
    }

    // Happy path: all matched and balanced.
    final noBankAccount = _selectedBankAccountId == null;
    return Card(
      color: noBankAccount ? Colors.orange.shade50 : Colors.green.shade50,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: noBankAccount
                  ? Colors.orange.shade200
                  : Colors.green.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
                noBankAccount
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outlined,
                color: noBankAccount
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
                size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      noBankAccount
                          ? 'Select a bank account to lock'
                          : 'Reconciliation complete',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: noBankAccount
                              ? Colors.orange.shade800
                              : Colors.green.shade800)),
                  const SizedBox(height: 4),
                  Text(
                    noBankAccount
                        ? 'All transactions are matched and balances agree. '
                            'Select a bank account above to record the closing balance.'
                        : 'All ${txs.length} transaction${txs.length == 1 ? '' : 's'} are bank-matched '
                            'and the closing balance matches.',
                    style: TextStyle(
                        fontSize: 13,
                        color: noBankAccount
                            ? Colors.orange.shade700
                            : Colors.green.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: (_locking || noBankAccount) ? null : _lockMonth,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700),
              icon: _locking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_outlined, size: 16),
              label: const Text('Lock month'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            if (trailing != null) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          ],
        ),
      ),
    );
  }

  // ── Matching phase UI ─────────────────────────────────────────────────────────

  Widget _buildMatching() {
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
        if (_allRowsResolved) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => setState(() => _phase = _Phase.results),
                icon: const Icon(Icons.check_outlined, size: 16),
                label: const Text('Review & lock'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryBar() {
    final stmt = _statement!;
    final matchedCount = _rows.where((r) => r.isResolved).length;
    final needsActionCount = _rows.where((r) => r.needsAction).length;
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 16),
          const SizedBox(width: 6),
          Text(stmt.statementPeriod,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          SummaryIndicator(
            icon: Icons.check_circle_outline,
            label: '$matchedCount matched',
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          if (needsActionCount > 0)
            SummaryIndicator(
              icon: Icons.warning_amber_outlined,
              label: '$needsActionCount need attention',
              color: Colors.orange,
            ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _phase = _Phase.results),
            child: const Text('Back to results'),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(_RecRow row) {
    final isDebit = row.source.isDebit;
    final color = isDebit ? Colors.red.shade700 : Colors.green.shade700;
    final amtText = isDebit
        ? '-${formatAmount(row.source.amountCents)}'
        : formatAmount(row.source.amountCents);

    return DataRow(cells: [
      DataCell(Text(row.processDate,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
      DataCell(ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(row.source.description,
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
          bankAmount: row.source.amountCents,
          parsedReceipts: row.parsedReceipts,
        ),
      )),
      DataCell(_actionCell(row)),
    ]);
  }

  Widget _actionCell(_RecRow row) {
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
          onPressed: () => _openManualMatch(row),
          child: Text(row.matched.isEmpty ? 'Select...' : 'Change...'),
        ),
        IconButton(
          icon: const Icon(Icons.not_interested_outlined, size: 18),
          tooltip: 'Skip',
          onPressed: () => _toggleSkip(row),
          color: Colors.grey,
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _yearMonth(String date) =>
      date.length >= 7 ? date.substring(0, 7) : date;

  static String _centsToDisplay(int cents) {
    final dollars = cents ~/ 100;
    final remaining = cents.abs() % 100;
    return '$dollars.${remaining.toString().padLeft(2, '0')}';
  }

  static int? _parseCentsFromDisplay(String s) {
    final cleaned = s.replaceAll(',', '').replaceAll('\$', '').trim();
    final d = double.tryParse(cleaned);
    if (d == null) return null;
    return (d * 100).round();
  }
}
