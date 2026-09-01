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
import 'package:provider/provider.dart';

import '../models/bank_account_summary.dart';
import '../models/bank_import_entry.dart';
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/invoice_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../services/reference_data_cache.dart';
import '../utils/bank_row_matching.dart';
import '../utils/cba_receipt_parser.dart';
import '../utils/receipt_format.dart';
import '../widgets/bank_match_widgets.dart';
import '../widgets/gl_account_dropdown.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class _CbaRow {
  final String processDate; // YYYY-MM-DD
  final String description;
  final bool isBankDebit; // true = money left the account
  final int amountCents;

  List<String> parsedReceipts;
  BankMatchStatus status = BankMatchStatus.unmatched;
  List<TransactionEntry> matched = const [];
  InvoiceEntry? invoiceMatch;

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
      status == BankMatchStatus.newTransaction ||
      status == BankMatchStatus.invoiceMatched;
}

// ── Matching logic (pure, unit-tested) ──────────────────────────────────────

/// Result of matching a single bank statement row against the ledger.
typedef CbaRowMatchResult = ({BankMatchStatus status, List<TransactionEntry> matched});

/// Matching decision for a debit ("Money-Out") bank statement row. Pulled out
/// as a top-level function (rather than kept as a private [State] method) so
/// it can be unit tested directly with plain Dart values, independent of
/// Flutter widget infrastructure — see `test/utils/import_cba_matching_test.dart`.
CbaRowMatchResult matchCbaDebitRow({
  required List<TransactionEntry> allTransactions,
  required Set<String> reservedIds,
  required String? selectedBankAccountId,
  required List<String> parsedReceipts,
  required String description,
  required int amountCents,
  required String processDate,
  required Map<String, String> contactNames,
}) {
  final referencedTxns = allTransactions
      .where((t) => referenceMatches(
            parsedReceipts: parsedReceipts,
            description: description,
            transaction: t,
          ))
      .toList();

  if (parsedReceipts.isNotEmpty || referencedTxns.isNotEmpty) {
    final found = referencedTxns
        .where((t) =>
            !t.bankMatched &&
            !reservedIds.contains(t.id) &&
            (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
            t.transactionType == 'debit')
        .toList();

    if (found.isEmpty) {
      final alreadyMatchedList = referencedTxns
          .where((t) =>
              t.bankMatched &&
              (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
              t.transactionType == 'debit')
          .toList();
      final alreadyMatchedTotal =
          alreadyMatchedList.fold(0, (int s, t) => s + t.totalAmount);
      return (
        status: (alreadyMatchedList.isNotEmpty && alreadyMatchedTotal == amountCents)
            ? BankMatchStatus.alreadyImported
            : BankMatchStatus.unmatched,
        matched: [],
      );
    }

    final subset = findMatchingSubset(found, amountCents);
    return (
      status: subset != null ? BankMatchStatus.autoMatched : BankMatchStatus.amountMismatch,
      matched: subset ?? found,
    );
  }

  // No P-numbers or payment references recognised — check for a WMS ABA batch name in the description.
  final batchName = extractAbaBatchName(description);
  if (batchName != null) {
    final found = allTransactions
        .where((t) =>
            !t.bankMatched &&
            !reservedIds.contains(t.id) &&
            (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
            t.transactionType == 'debit' &&
            t.abaBatchName == batchName)
        .toList();
    if (found.isNotEmpty) {
      final subset = findMatchingSubset(found, amountCents);
      return (
        status: subset != null ? BankMatchStatus.autoMatched : BankMatchStatus.amountMismatch,
        matched: subset ?? found,
      );
    }
  }

  // Fall back to date + amount.
  final candidates = allTransactions
      .where((t) =>
          !t.bankMatched &&
          !reservedIds.contains(t.id) &&
          (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
          t.transactionType == 'debit' &&
          t.transactionDate == processDate &&
          t.totalAmount == amountCents)
      .toList();

  if (candidates.length == 1) {
    return (status: BankMatchStatus.autoMatched, matched: candidates);
  } else if (candidates.length > 1) {
    final disambiguated = disambiguateByContactName(candidates, description, contactNames);
    return disambiguated != null
        ? (status: BankMatchStatus.autoMatched, matched: disambiguated)
        : (status: BankMatchStatus.needsSelection, matched: candidates);
  } else {
    // A single already-matched transaction may not carry the full bank
    // amount on its own — e.g. an invoice with several line items is
    // split into one transaction per line item. Check whether some
    // subset of already-matched transactions on this date sums to it.
    final alreadyMatchedTxns = allTransactions
        .where((t) =>
            t.bankMatched &&
            (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
            t.transactionType == 'debit' &&
            t.transactionDate == processDate)
        .toList();
    final alreadyMatched = findMatchingSubset(alreadyMatchedTxns, amountCents) != null;
    return (
      status: alreadyMatched ? BankMatchStatus.alreadyImported : BankMatchStatus.unmatched,
      matched: [],
    );
  }
}

/// Matching decision for a credit ("Money-In") bank statement row. See
/// [matchCbaDebitRow] for why this is a top-level function.
CbaRowMatchResult matchCbaCreditRow({
  required List<TransactionEntry> allTransactions,
  required Set<String> reservedIds,
  required String? selectedBankAccountId,
  required List<String> parsedReceipts,
  required String description,
  required int amountCents,
  required String processDate,
  required Map<String, String> contactNames,
}) {
  if (parsedReceipts.isNotEmpty) {
    final found = allTransactions
        .where((t) =>
            !t.bankMatched &&
            !reservedIds.contains(t.id) &&
            (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
            t.transactionType == 'credit' &&
            parsedReceipts.contains(t.receiptNumber))
        .toList();

    if (found.isNotEmpty) {
      final subset = findMatchingSubset(found, amountCents);
      return (
        status: subset != null ? BankMatchStatus.autoMatched : BankMatchStatus.amountMismatch,
        matched: subset ?? found,
      );
    }

    // No un-matched transaction for receipt — check if already bank-matched.
    final alreadyMatchedByReceipt = allTransactions
        .where((t) =>
            t.bankMatched &&
            (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
            t.transactionType == 'credit' &&
            parsedReceipts.contains(t.receiptNumber))
        .toList();
    final alreadyMatchedTotal =
        alreadyMatchedByReceipt.fold(0, (int s, t) => s + t.totalAmount);
    if (alreadyMatchedByReceipt.isNotEmpty && alreadyMatchedTotal == amountCents) {
      return (status: BankMatchStatus.alreadyImported, matched: []);
    }
  }

  // No receipt match — fall back to date + amount.
  final candidates = allTransactions
      .where((t) =>
          !t.bankMatched &&
          !reservedIds.contains(t.id) &&
          (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
          t.transactionType == 'credit' &&
          t.transactionDate == processDate &&
          t.totalAmount == amountCents)
      .toList();

  if (candidates.length == 1) {
    return (status: BankMatchStatus.autoMatched, matched: candidates);
  } else if (candidates.length > 1) {
    final disambiguated = disambiguateByContactName(candidates, description, contactNames);
    return disambiguated != null
        ? (status: BankMatchStatus.autoMatched, matched: disambiguated)
        : (status: BankMatchStatus.needsSelection, matched: candidates);
  } else {
    // A single already-matched transaction may not carry the full bank
    // amount on its own — e.g. an invoice with several line items is
    // split into one transaction per line item. Check whether some
    // subset of already-matched transactions on this date sums to it.
    final alreadyMatchedTxns = allTransactions
        .where((t) =>
            t.bankMatched &&
            (t.bankAccountId == null || t.bankAccountId == selectedBankAccountId) &&
            t.transactionType == 'credit' &&
            t.transactionDate == processDate)
        .toList();
    final alreadyMatched = findMatchingSubset(alreadyMatchedTxns, amountCents) != null;
    return (
      status: alreadyMatched ? BankMatchStatus.alreadyImported : BankMatchStatus.unmatched,
      matched: [],
    );
  }
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
  List<InvoiceEntry> _unpaidInvoices = [];

  // Contacts and GL accounts live in the shared [ReferenceDataCache] so that
  // edits made on other screens (e.g. adding a contact or GL account) are
  // reflected here immediately, even though this screen's State can be
  // retained on the Navigator stack while the user visits other screens.
  List<ContactEntry> get _contacts => context.read<ReferenceDataCache>().contacts;
  List<GeneralLedgerEntry> get _glEntries => context.read<ReferenceDataCache>().glEntries;
  List<BankAccountSummary> get _bankAccounts =>
      context.read<ReferenceDataCache>().bankAccountSummaries;
  Map<String, String> get _contactNames =>
      {for (final c in _contacts) c.id: c.name}; // contactId → display name

  // Bank account the imported CSV rows belong to. The CBA statement CSV has
  // no account identifier of its own, so the user must pick it up front.
  String? _selectedBankAccountId;
  String? get _selectedBankAccountName {
    final id = _selectedBankAccountId;
    if (id == null) return null;
    for (final a in _bankAccounts) {
      if (a.id == id) return a.accountName;
    }
    return null;
  }

  ReceiptFormat _moneyInFormat = const ReceiptFormat('');
  ReceiptFormat _moneyOutFormat = const ReceiptFormat('');

  /// Dedup keys for rows already recorded in a previous import session.
  Set<String> _importedKeys = {};

  bool _fileParsed = false;
  String _fileName = '';
  List<_CbaRow> _rows = [];

  /// Transaction IDs already matched during this import session.
  final Set<String> _reservedIds = {};
  // IDs reserved by partial (amount-mismatched) manual matches — still shown in other rows' dropdowns.
  final Set<String> _partialMatchIds = {};

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

      final cache = context.read<ReferenceDataCache>();
      await Future.wait([
        cache.ensureContactsLoaded(),
        cache.ensureGlLoaded(),
        cache.ensureBankAccountSummariesLoaded(),
      ]);
      if (!mounted) return;
      if (cache.contactsStatus == LoadStatus.error) {
        throw Exception(cache.contactsError ?? 'Failed to load contacts');
      }
      if (cache.glStatus == LoadStatus.error) {
        throw Exception(cache.glError ?? 'Failed to load GL accounts');
      }
      if (cache.bankAccountSummariesStatus == LoadStatus.error) {
        throw Exception(
            cache.bankAccountSummariesError ?? 'Failed to load bank accounts');
      }

      // Pre-select if only one bank account exists.
      if (cache.bankAccountSummaries.length == 1 &&
          _selectedBankAccountId == null) {
        _selectedBankAccountId = cache.bankAccountSummaries.first.id;
      }

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

      final invRes = await client.get('/invoices?unpaid=true');
      if (invRes.statusCode == 200) {
        final list = jsonDecode(invRes.body) as List<dynamic>;
        _unpaidInvoices = list
            .map((j) => InvoiceEntry.fromJson(j as Map<String, dynamic>))
            .toList();
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
    _partialMatchIds.clear();
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
    final result = matchCbaDebitRow(
      allTransactions: _allTransactions,
      reservedIds: _reservedIds,
      selectedBankAccountId: _selectedBankAccountId,
      parsedReceipts: row.parsedReceipts,
      description: row.description,
      amountCents: row.amountCents,
      processDate: row.processDate,
      contactNames: _contactNames,
    );
    row.status = result.status;
    row.matched = result.matched;
  }

  void _matchCreditRow(_CbaRow row) {
    final result = matchCbaCreditRow(
      allTransactions: _allTransactions,
      reservedIds: _reservedIds,
      selectedBankAccountId: _selectedBankAccountId,
      parsedReceipts: row.parsedReceipts,
      description: row.description,
      amountCents: row.amountCents,
      processDate: row.processDate,
      contactNames: _contactNames,
    );
    row.status = result.status;
    row.matched = result.matched;
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
      s == BankMatchStatus.alreadyImported ||
      s == BankMatchStatus.invoiceMatched;

  // ── Manual matching dialog ────────────────────────────────────────────────────

  Future<void> _openManualMatch(_CbaRow row) async {
    final rowIndex = _rows.indexOf(row);

    // Release this row's current matches so they appear as selectable.
    for (final t in row.matched) {
      _reservedIds.remove(t.id);
      _partialMatchIds.remove(t.id);
    }

    final String type = row.isBankDebit ? 'debit' : 'credit';
    final month = _yearMonth(row.processDate);
    final candidates = _allTransactions
        .where((t) =>
            !t.bankMatched &&
            (!_reservedIds.contains(t.id) || _partialMatchIds.contains(t.id)) &&
            (t.bankAccountId == null ||
                t.bankAccountId == _selectedBankAccountId) &&
            t.transactionType == type &&
            _yearMonth(t.transactionDate) == month)
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    // For credit rows, offer unpaid invoices that match the exact bank amount.
    final invoiceCandidates = !row.isBankDebit
        ? _unpaidInvoices
            .where((inv) => inv.totalWithGstCents == row.amountCents)
            .toList()
        : <InvoiceEntry>[];

    final result = await showDialog<ManualMatchResult>(
      context: context,
      builder: (ctx) => ManualMatchDialog(
        description: row.description,
        processDate: row.processDate,
        bankAmountCents: row.amountCents,
        candidates: candidates,
        contactNames: _contactNames,
        initialSelection: Set<String>.from(row.matched.map((t) => t.id)),
        invoiceMatches: invoiceCandidates,
        initialInvoice: row.invoiceMatch,
      ),
    );

    if (result == null) {
      // Cancelled — restore previous transaction matches.
      final prevTotal =
          row.matched.fold(0, (s, t) => s + t.totalAmount);
      final prevIsPartial =
          row.matched.isNotEmpty && prevTotal != row.amountCents;
      for (final t in row.matched) {
        _reservedIds.add(t.id);
        if (prevIsPartial) _partialMatchIds.add(t.id);
      }
      return;
    }

    setState(() {
      switch (result) {
        case InvoiceMatchResult(:final invoice):
          row.invoiceMatch = invoice;
          row.matched = [];
          row.status = BankMatchStatus.invoiceMatched;
          _recomputeFrom(rowIndex + 1);
        case TransactionMatchResult(:final transactions):
          row.invoiceMatch = null;
          final matchedTotal =
              transactions.fold(0, (s, t) => s + t.totalAmount);
          final isPartial =
              transactions.isNotEmpty && matchedTotal != row.amountCents;
          for (final t in transactions) {
            _reservedIds.add(t.id);
            if (isPartial) _partialMatchIds.add(t.id);
          }
          row.matched = transactions;
          row.status = transactions.isEmpty
              ? BankMatchStatus.unmatched
              : BankMatchStatus.manuallyMatched;
          _recomputeFrom(rowIndex + 1);
      }
    });
  }

  // ── Create new transaction ───────────────────────────────────────────────────

  Future<void> _openCreateTransaction(_CbaRow row) async {
    final rowIndex = _rows.indexOf(row);

    final format = row.isBankDebit ? _moneyOutFormat : _moneyInFormat;
    final existingReceipts =
        _allTransactions.map((t) => t.receiptNumber).toList();
    final nextReceipt = format.nextReceipt(existingReceipts);

    final result = await showDialog<TransactionEntry>(
      context: context,
      builder: (ctx) => _CreateTransactionDialog(
        row: row,
        contacts: _contacts,
        glEntries: _glEntries,
        api: context.read<ApiClient>(),
        nextReceipt: nextReceipt,
        bankAccountId: _selectedBankAccountId,
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
        for (final t in row.matched) {
          _reservedIds.remove(t.id);
          _partialMatchIds.remove(t.id);
        }
        row.matched = [];
        row.invoiceMatch = null;
        row.status = BankMatchStatus.skipped;
        _recomputeFrom(rowIndex + 1);
      }
    });
  }

  // ── Confirm ───────────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    // Manually matched rows are grouped by the bank row's clearing date and
    // sent with that date, so the transaction's date gets stamped to it —
    // otherwise a manual match against a mismatched reference keeps its
    // original date and is invisible to date-based re-detection on the next
    // import. Everything else (auto-matched by receipt, new transactions
    // already created with the right date) is sent without a date so its
    // existing, correct date is left untouched.
    final manualIdsByDate = <String, List<String>>{};
    final otherIds = <String>[];
    for (final row in _rows.where((r) => r.isResolved)) {
      for (final t in row.matched) {
        if (row.status == BankMatchStatus.manuallyMatched) {
          manualIdsByDate.putIfAbsent(row.processDate, () => []).add(t.id);
        } else {
          otherIds.add(t.id);
        }
      }
    }

    final hasInvoiceRows = _rows.any((r) => r.invoiceMatch != null);

    if (manualIdsByDate.isEmpty && otherIds.isEmpty && !hasInvoiceRows) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _saving = true);

    try {
      final client = context.read<ApiClient>();

      if (otherIds.isNotEmpty) {
        final matchRes = await client.post(
          '/transactions/bank-match',
          jsonEncode({
            'transactionIds': otherIds,
            'bankAccountId': _selectedBankAccountId,
          }),
        );
        if (matchRes.statusCode != 204) {
          throw Exception('Server returned ${matchRes.statusCode}');
        }
      }

      for (final entry in manualIdsByDate.entries) {
        final matchRes = await client.post(
          '/transactions/bank-match',
          jsonEncode({
            'transactionIds': entry.value,
            'bankAccountId': _selectedBankAccountId,
            'transactionDate': entry.key,
          }),
        );
        if (matchRes.statusCode != 204) {
          throw Exception('Server returned ${matchRes.statusCode}');
        }
      }

      // Mark invoice-matched rows as paid.
      final invoiceRows =
          _rows.where((r) => r.invoiceMatch != null).toList();
      for (final row in invoiceRows) {
        final invoice = row.invoiceMatch!;
        final res = await client.post(
          '/invoices/${invoice.id}/mark-paid',
          jsonEncode({'transactionDate': row.processDate}),
        );
        if (res.statusCode != 200) {
          final msg = (jsonDecode(res.body) as Map?)?['error'] ??
              'Failed to mark invoice ${invoice.invoiceNumber} as paid';
          throw Exception(msg);
        }
        _unpaidInvoices =
            _unpaidInvoices.where((inv) => inv.id != invoice.id).toList();
      }

      // Record every actioned row so re-imports skip them.
      final rowsToRecord = _rows
          .where((r) =>
              r.status != BankMatchStatus.alreadyImported &&
              r.status != BankMatchStatus.unmatched &&
              r.status != BankMatchStatus.needsSelection &&
              r.status != BankMatchStatus.amountMismatch &&
              r.status != BankMatchStatus.skipped)
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
    // Registers this screen as a listener of the shared cache so it rebuilds
    // (and the Contact dropdown reflects new contacts) whenever contacts
    // change on another screen while this one is retained on the stack.
    context.watch<ReferenceDataCache>();
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
    final noBankAccounts = _bankAccounts.isEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Select a CBA bank statement CSV file to begin.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'The CSV does not identify its own account, so choose the '
            'bank account these transactions belong to.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 320,
            child: noBankAccounts
                ? const Text('No bank accounts configured.',
                    style: TextStyle(color: Colors.orange))
                : _buildBankAccountDropdown(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed:
                (noBankAccounts || _selectedBankAccountId == null) ? null : _pickFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Pick CSV File'),
          ),
        ],
      ),
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

  /// Returns true when ALL transactions on [row] are partially shared across
  /// multiple rows and the combined bank amounts of those rows exactly equal
  /// each transaction's total — meaning the split is fully accounted for.
  bool _suppressMismatch(_CbaRow row) {
    if (row.matched.isEmpty) return false;
    for (final t in row.matched) {
      if (!_partialMatchIds.contains(t.id)) return false;
      final sharingTotal = _rows
          .where((r) => r.matched.any((m) => m.id == t.id))
          .fold(0, (s, r) => s + r.amountCents);
      if (sharingTotal != t.totalAmount) return false;
    }
    return true;
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
          const SizedBox(width: 16),
          const Icon(Icons.account_balance_outlined, size: 16),
          const SizedBox(width: 6),
          Text(_selectedBankAccountName ?? 'No account selected',
              style: theme.textTheme.bodySmall),
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
        child: row.invoiceMatch != null
            ? Text(
                row.invoiceMatch!.invoiceNumber,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal),
              )
            : MatchedToCell(
                receipts: row.matched.map((t) => t.receiptNumber).toList(),
                matchedTotal:
                    row.matched.fold(0, (int s, t) => s + t.totalAmount),
                bankAmount: row.amountCents,
                parsedReceipts: row.parsedReceipts,
                suppressMismatch: _suppressMismatch(row),
              ),
      )),
      DataCell(_actionCell(row)),
    ]);
  }

  Widget _actionCell(_CbaRow row) {
    if (row.status == BankMatchStatus.alreadyImported) {
      // Dedup key exists but no transaction was created — let the user create one.
      return IconButton(
        icon: const Icon(Icons.add_circle_outline, size: 18),
        tooltip: 'Create missing transaction',
        onPressed: _saving ? null : () => _openCreateTransaction(row),
        color: Colors.teal,
      );
    }

    if (row.status == BankMatchStatus.skipped) {
      return TextButton(
        onPressed: () => _toggleSkip(row),
        child: const Text('Unskip'),
      );
    }

    if (row.status == BankMatchStatus.invoiceMatched) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _saving ? null : () => _openManualMatch(row),
            child: const Text('Change...'),
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
  final String nextReceipt;
  final String? bankAccountId;

  const _CreateTransactionDialog({
    required this.row,
    required this.contacts,
    required this.glEntries,
    required this.api,
    required this.nextReceipt,
    required this.bankAccountId,
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
    // Money-In (credit) transactions created from a bank import are always
    // "Bank Transfer" — a sequential cash-style receipt number only applies
    // to cash transactions, which never come from a bank statement.
    _receiptController = TextEditingController(
      text: row.isBankDebit
          ? (row.parsedReceipts.length == 1
              ? row.parsedReceipts.first
              : widget.nextReceipt)
          : 'Bank Transfer',
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
    final receipt =
        widget.row.isBankDebit ? _receiptController.text.trim() : 'Bank Transfer';
    if (widget.row.isBankDebit && receipt.isEmpty) {
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
        'bankAccountId': widget.bankAccountId,
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
              GlAccountDropdown(
                allEntries: widget.glEntries,
                value: _gl,
                directionFilter: widget.row.isBankDebit
                    ? GlDirection.moneyOut
                    : GlDirection.moneyIn,
                compact: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => setState(() {
                  _gl = v;
                  _recalculate();
                }),
              ),
              const SizedBox(height: 12),

              // Receipt — Money-In (credit) transactions from a bank import are
              // always "Bank Transfer"; only Money-Out needs a receipt number.
              if (widget.row.isBankDebit) ...[
                _label('Receipt Number *'),
                TextField(
                  controller: _receiptController,
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: 12),
              ],

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
