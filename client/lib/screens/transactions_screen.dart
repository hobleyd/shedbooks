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
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/bank_account_entry.dart';
import '../models/bank_account_summary.dart';
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/gl_pair_filter.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../services/reference_data_cache.dart';
import '../utils/formatters.dart';
import 'import_cba_screen.dart';
import 'import_cashflow_manager_screen.dart';
import 'import_transactions_screen.dart';
import '../widgets/pdf_report_components.dart';
import '../widgets/transaction_form.dart';
import '../widgets/transaction_receipt_pdf.dart';
import '../widgets/transactions_pdf_report.dart';

/// Entry screen for creating transactions, with a month-view list above the form.
class TransactionsScreen extends StatefulWidget {
  final ContactEntry? initialContact;
  final GlPairFilter? initialGlPair;

  const TransactionsScreen({super.key, this.initialContact, this.initialGlPair});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  List<TransactionEntry> _allTransactions = [];
  int _nextMoneyOutSeq = 1;
  int? _sortColumn;
  bool _sortAscending = true;
  final Set<String> _selectedTransactionIds = {};

  late DateTime _viewMonth;

  // ── Contact / GL search / year-view state ─────────────────────────────────
  ContactEntry? _searchContact;
  GlPairFilter? _searchGlPair;
  int _searchYear = DateTime.now().year;
  int _searchResetKey = 0;

  // ── Inline add state ───────────────────────────────────────────────────────
  bool _addingMoneyIn = false;
  bool _addingMoneyOut = false;

  // ── Inline edit state ───────────────────────────────────────────────────────
  String? _editingId;
  bool _editSaving = false;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // Contacts and GL accounts live in the shared [ReferenceDataCache] so that
  // edits made on other screens (e.g. adding a contact) are reflected here
  // immediately, even though this screen's State is retained off-screen by
  // the IndexedStack while the user navigates elsewhere.
  List<ContactEntry> get _contacts => context.read<ReferenceDataCache>().contacts;
  List<GeneralLedgerEntry> get _glEntries => context.read<ReferenceDataCache>().glEntries;
  List<BankAccountEntry> get _bankAccounts => context.read<ReferenceDataCache>().bankAccounts;
  // Unlike [_bankAccounts] (admin-only), summaries are available to every
  // authenticated role — used to populate the transaction form's account
  // dropdown, which contributors also need when creating transactions.
  List<BankAccountSummary> get _bankAccountSummaries =>
      context.read<ReferenceDataCache>().bankAccountSummaries;
  EntityDetails? get _entityDetails => context.read<ReferenceDataCache>().entityDetails;

  /// A month is locked only when every bank account has it locked. When bank
  /// accounts are unavailable (non-admin role), treat any entry in the
  /// locked-months list as locked to prevent edits to locked months.
  Set<String> get _lockedMonths {
    final cache = context.read<ReferenceDataCache>();
    final bankAccounts = cache.bankAccounts;
    if (bankAccounts.isEmpty) {
      return cache.lockedMonths.map((e) => e.monthYear).toSet();
    }
    final Map<String, Set<String>> accountsByMonth = {};
    for (final entry in cache.lockedMonths) {
      accountsByMonth.putIfAbsent(entry.monthYear, () => {}).add(entry.bankAccountId);
    }
    return accountsByMonth.entries
        .where((e) => e.value.length >= bankAccounts.length)
        .map((e) => e.key)
        .toSet();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    final glPair = widget.initialGlPair;
    final startOnMoneyOut = widget.initialContact != null;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: startOnMoneyOut ? 1 : 0,
    );
    if (startOnMoneyOut) {
      _searchContact = widget.initialContact;
      _searchYear = now.year;
    }
    if (glPair != null) {
      _searchGlPair = glPair;
      _searchYear = now.year;
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen old) {
    super.didUpdateWidget(old);
    // With state retention, the existing State is reused when the user
    // re-navigates to /transactions. If a different contact or GL entry
    // arrives via `extra`, update the filter. Reference data comes from the
    // shared ReferenceDataCache, which stays current on its own.
    final newContact = widget.initialContact;
    if (newContact != null && newContact.id != old.initialContact?.id) {
      setState(() {
        _searchContact = newContact;
        _searchGlPair = null;
        _searchYear = DateTime.now().year;
        _tabController.index = 1;
      });
    }

    final newPair = widget.initialGlPair;
    if (newPair != null && (newPair.incomeGl.id != old.initialGlPair?.incomeGl.id ||
        newPair.expenseGl.id != old.initialGlPair?.expenseGl.id)) {
      setState(() {
        _searchGlPair = newPair;
        _searchContact = null;
        _searchYear = DateTime.now().year;
        _tabController.index = 0;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final cache = context.read<ReferenceDataCache>();
      final results = await Future.wait([client.get('/transactions')]);
      // Reference data is shared across every screen via the cache;
      // refreshing it here keeps this screen's historical "reload
      // everything" behavior while also propagating the fresh data to any
      // other screen watching the cache.
      await Future.wait([
        cache.refreshContacts(),
        cache.refreshGl(),
        cache.refreshBankAccounts(),
        cache.refreshBankAccountSummaries(),
        cache.refreshEntityDetails(),
        cache.refreshLockedMonths(),
      ]);

      if (!mounted) return;

      if (results[0].statusCode != 200 ||
          cache.contactsStatus == LoadStatus.error ||
          cache.glStatus == LoadStatus.error) {
        setState(() {
          _loadError = 'Failed to load reference data';
          _loading = false;
        });
        return;
      }

      final transactions = (jsonDecode(results[0].body) as List)
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

      setState(() {
        _allTransactions = transactions;
        _nextMoneyOutSeq = _computeNextMoneyOutSeq(transactions);
        _loading = false;
        _applySort();
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

  void _handleBankUpload() async {
    if (_selectedTransactionIds.isEmpty) return;

    if (_entityDetails == null ||
        _entityDetails!.apcaId == null ||
        _entityDetails!.apcaId!.isEmpty) {
      _showSnackbar('Entity APCA ID is missing. Please update Entity Details.');
      return;
    }

    if (_bankAccounts.isEmpty) {
      _showSnackbar('No bank accounts configured.');
      return;
    }

    // Identify selected transactions
    final selectedTxns = _allTransactions
        .where((t) => _selectedTransactionIds.contains(t.id))
        .toList();

    // Check for missing contact bank details
    final missingDetails = <String>[];
    for (final t in selectedTxns) {
      final contact = _contacts.firstWhere((c) => c.id == t.contactId);
      if (contact.bsb == null ||
          contact.bsb!.isEmpty ||
          contact.accountNumber == null ||
          contact.accountNumber!.isEmpty) {
        missingDetails.add(contact.name);
      }
    }

    if (missingDetails.isNotEmpty) {
      _showSnackbar(
          'Missing bank details for: ${missingDetails.join(", ")}. Please update Contacts.');
      return;
    }

    // Select sender bank account if multiple (system accounts excluded — no real banking details).
    final eligibleAccounts = _bankAccounts.where((a) => !a.isSystem).toList();
    BankAccountEntry? senderAccount;
    if (eligibleAccounts.length == 1) {
      senderAccount = eligibleAccounts.first;
    } else {
      senderAccount = await showDialog<BankAccountEntry>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Sender Bank Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: eligibleAccounts
                .map((a) => ListTile(
                      title: Text(a.accountName),
                      subtitle: Text('${a.bsbFormatted} ${a.accountNumber}'),
                      onTap: () => Navigator.of(ctx).pop(a),
                    ))
                .toList(),
          ),
        ),
      );
    }

    if (senderAccount == null) return;

    // Generate ABA
    try {
      final apiClient = context.read<ApiClient>();
      final references = selectedTxns.map((t) => t.receiptNumber).toList();
      final seqResponse = await apiClient.post(
        '/aba-sequences/next',
        jsonEncode({'references': references}),
      );
      if (seqResponse.statusCode != 200) {
        _showSnackbar('Failed to get ABA sequence number.');
        return;
      }
      final seqJson = jsonDecode(seqResponse.body) as Map<String, dynamic>;
      final sequence = seqJson['sequence'] as int;

      final now = DateTime.now();
      final seq = sequence.toString().padLeft(3, '0');
      final wmsName =
          'WMS${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$seq';
      final abaContent = _generateAba(selectedTxns, senderAccount, sequence);
      final bytes = utf8.encode(abaContent);
      final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      (web.document.createElement('a') as web.HTMLAnchorElement)
        ..href = url
        ..download = '$wmsName.aba'
        ..click();
      web.URL.revokeObjectURL(url);

      // Record the batch name against each transaction for auto-matching during import.
      final batchRes = await apiClient.post(
        '/transactions/aba-batch',
        jsonEncode({
          'transactionIds': selectedTxns.map((t) => t.id).toList(),
          'batchName': wmsName,
        }),
      );
      if (batchRes.statusCode != 204) {
        _showSnackbar('ABA file generated but batch name could not be recorded.');
      } else {
        _showSnackbar('ABA file generated.');
      }
      setState(() => _selectedTransactionIds.clear());
    } catch (e) {
      _showSnackbar('Failed to generate ABA: $e');
    }
  }

  String _generateAba(
      List<TransactionEntry> txns, BankAccountEntry sender, int sequence) {
    final buffer = StringBuffer();

    // Record 0: Descriptive Record
    // 01: Record Type (1) - '0'
    // 02-18: Blank (17)
    // 19-20: Reel Sequence Number (2) - '01'
    // 21-23: Name of User's Financial Institution (3) - e.g. 'CBA'
    // 24-30: Blank (7)
    // 31-56: Name of User Supplying File (26)
    // 57-62: Number of User Supplying File (6) - APCA ID
    // 63-74: Description of entries (12) - e.g. 'PAYMENTS'
    // 75-80: Date to be processed (6) - DDMMYY
    // 81-120: Blank (40)

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';
    final wmsName = 'WMS${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${sequence.toString().padLeft(3, '0')}';

    buffer.write('0'); // 01
    buffer.write(' ' * 17); // 02-18
    buffer.write('01'); // 19-20
    buffer.write(sender.bankName.padRight(3).substring(0, 3).toUpperCase()); // 21-23
    buffer.write(' ' * 7); // 24-30
    buffer.write(_entityDetails!.name.padRight(26).substring(0, 26).toUpperCase()); // 31-56
    buffer.write(_entityDetails!.apcaId!.padLeft(6, '0')); // 57-62
    buffer.write(wmsName.padRight(12)); // 63-74
    buffer.write(dateStr); // 75-80
    buffer.write(' ' * 40); // 81-120
    buffer.write('\r\n');

    int totalCents = 0;
    int recordCount = 0;

    for (final t in txns) {
      final contact = _contacts.firstWhere((c) => c.id == t.contactId);
      final bsb = contact.bsb!.replaceAll(RegExp(r'[^0-9]'), '');
      final accNo = contact.accountNumber!.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = t.totalAmount;
      final name = contact.name.padRight(32).substring(0, 32).toUpperCase();
      final ref = t.receiptNumber.padRight(18).substring(0, 18);

      // Record 1: Detail Record
      // 01: Record Type (1) - '1'
      // 02-08: BSB (7) - XXX-XXX (with dash)
      // 09-17: Account Number (9) - Right justified, blank filled
      // 18: Indicator (1) - Blank
      // 19-20: Transaction Code (2) - '50' for credit (we are paying them)
      // 21-30: Amount (10) - Cents, zero filled
      // 31-62: Title of Account (32)
      // 63-80: Lodgement Reference (18)
      // 81-87: Trace BSB (7) - Sender BSB
      // 88-96: Trace Account Number (9)
      // 97-112: Name of Remitter (16)
      // 113-120: Amount of Withholding Tax (8) - Zero filled

      final bsbFormatted = '${bsb.substring(0, 3)}-${bsb.substring(3)}';
      final senderBsb = sender.bsb.replaceAll(RegExp(r'[^0-9]'), '');
      final senderBsbFormatted = '${senderBsb.substring(0, 3)}-${senderBsb.substring(3)}';
      final senderAccNo = sender.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');

      buffer.write('1'); // 01
      buffer.write(bsbFormatted.substring(0, 7)); // 02-08
      buffer.write(accNo.padLeft(9).substring(0, 9)); // 09-17
      buffer.write(' '); // 18
      buffer.write('50'); // 19-20
      buffer.write(amount.toString().padLeft(10, '0').substring(0, 10)); // 21-30
      buffer.write(name.substring(0, 32)); // 31-62
      buffer.write(ref.substring(0, 18)); // 63-80
      buffer.write(senderBsbFormatted.substring(0, 7)); // 81-87
      buffer.write(senderAccNo.padLeft(9).substring(0, 9)); // 88-96
      buffer.write(_entityDetails!.name.padRight(16).substring(0, 16).toUpperCase()); // 97-112
      buffer.write('0' * 8); // 113-120
      buffer.write('\r\n');

      totalCents += amount;
      recordCount++;
    }

    // Record 1: Contra (balancing) debit record — debits sender's account for the total.
    // Transaction code 13 = Other Debit.
    // The bank validates the contra BSB/account against their customer database, so
    // non-numeric characters must be stripped before padding to avoid lookup failures.
    final senderBsb = sender.bsb.replaceAll(RegExp(r'[^0-9]'), '');
    final senderBsbFormatted = '${senderBsb.substring(0, 3)}-${senderBsb.substring(3)}';
    final senderAccNo = sender.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    buffer.write('1'); // 01
    buffer.write(senderBsbFormatted.substring(0, 7)); // 02-08
    buffer.write(senderAccNo.padLeft(9).substring(0, 9)); // 09-17
    buffer.write(' '); // 18
    buffer.write('13'); // 19-20
    buffer.write(totalCents.toString().padLeft(10, '0').substring(0, 10)); // 21-30
    buffer.write(sender.accountName.padRight(32).substring(0, 32).toUpperCase()); // 31-62
    buffer.write(wmsName.padRight(18).substring(0, 18)); // 63-80
    buffer.write(senderBsbFormatted.substring(0, 7)); // 81-87
    buffer.write(senderAccNo.padLeft(9).substring(0, 9)); // 88-96
    buffer.write(_entityDetails!.name.padRight(16).substring(0, 16).toUpperCase()); // 97-112
    buffer.write('0' * 8); // 113-120
    buffer.write('\r\n');

    // Record 7: File Total Record
    // 01: Record Type (1) - '7'
    // 02-08: BSB Format Filler (7) - '999-999'
    // 09-20: Blank (12)
    // 21-30: Net Total Amount (10) - Zero when file is balanced (credits == debits)
    // 31-40: Credit Total Amount (10) - Cents
    // 41-50: Debit Total Amount (10) - Cents (contra record)
    // 51-74: Blank (24)
    // 75-80: Count of Detail Records (6) - includes the contra record
    // 81-120: Blank (40)

    buffer.write('7'); // 01
    buffer.write('999-999'); // 02-08
    buffer.write(' ' * 12); // 09-20
    buffer.write('0'.padLeft(10, '0')); // 21-30 net = 0 (balanced)
    buffer.write(totalCents.toString().padLeft(10, '0')); // 31-40 credit total
    buffer.write(totalCents.toString().padLeft(10, '0')); // 41-50 debit total (contra)
    buffer.write(' ' * 24); // 51-74
    buffer.write((recordCount + 1).toString().padLeft(6, '0')); // 75-80 includes contra
    buffer.write(' ' * 40); // 81-120
    buffer.write('\r\n');

    return buffer.toString();
  }

  int _computeNextMoneyOutSeq(List<TransactionEntry> transactions) {
    final yearStr = (DateTime.now().year % 100).toString().padLeft(2, '0');
    final regex = RegExp('^P-$yearStr(\\d{3})\$');
    int maxSeq = 0;
    for (final t in transactions) {
      final match = regex.firstMatch(t.receiptNumber);
      if (match != null) {
        final seq = int.tryParse(match.group(1)!) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    return maxSeq + 1;
  }

  String _formatMoneyOutReceipt() {
    final yearStr = (DateTime.now().year % 100).toString().padLeft(2, '0');
    return 'P-$yearStr${_nextMoneyOutSeq.toString().padLeft(3, '0')}';
  }

  List<TransactionEntry> get _viewMonthTransactions => _allTransactions
      .where((t) => t.transactionDate.startsWith(
          '${_viewMonth.year}-${_viewMonth.month.toString().padLeft(2, '0')}'))
      .toList();

  bool get _isSearchMode => _searchContact != null;
  bool get _isGlMode => _searchGlPair != null;

  List<TransactionEntry> get _searchResults => _allTransactions
      .where((t) =>
          t.contactId == _searchContact!.id &&
          t.transactionDate.startsWith('$_searchYear'))
      .toList();

  List<TransactionEntry> get _searchGlResults => _allTransactions
      .where((t) =>
          (t.generalLedgerId == _searchGlPair!.incomeGl.id ||
           t.generalLedgerId == _searchGlPair!.expenseGl.id) &&
          t.transactionDate.startsWith('$_searchYear'))
      .toList();

  bool get _canGoForward {
    final now = DateTime.now();
    return _viewMonth.year < now.year ||
        (_viewMonth.year == now.year && _viewMonth.month < now.month);
  }

  void _prevMonth() => setState(() =>
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1));

  void _nextMonth() {
    if (_canGoForward) {
      setState(() =>
          _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1));
    }
  }

  void _applySort() {
    if (_sortColumn == null) return;
    _allTransactions.sort((a, b) {
      final int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.transactionDate.compareTo(b.transactionDate);
        case 1:
          cmp = (_contactName(a.contactId) ?? '').toLowerCase().compareTo(
              (_contactName(b.contactId) ?? '').toLowerCase());
        case 2:
          cmp = (_glDescription(a.generalLedgerId) ?? '').toLowerCase().compareTo(
              (_glDescription(b.generalLedgerId) ?? '').toLowerCase());
        case 3:
          cmp = a.description.toLowerCase().compareTo(b.description.toLowerCase());
        case 4:
          cmp = a.receiptNumber
              .toLowerCase()
              .compareTo(b.receiptNumber.toLowerCase());
        case 5:
          cmp = a.totalAmount.compareTo(b.totalAmount);
        default:
          return 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  Widget _colHeader(String label, int col,
      {MainAxisAlignment align = MainAxisAlignment.start}) {
    final isActive = _sortColumn == col;
    return InkWell(
      onTap: () => setState(() {
        if (_sortColumn == col) {
          _sortAscending = !_sortAscending;
        } else {
          _sortColumn = col;
          _sortAscending = true;
        }
        _applySort();
      }),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisAlignment: align,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isDateLocked(DateTime date) {
    final monthYear = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    return _lockedMonths.contains(monthYear);
  }

  bool _isTransactionLocked(TransactionEntry t) {
    try {
      return _isDateLocked(DateTime.parse(t.transactionDate));
    } catch (_) {
      return false;
    }
  }

  String? _contactName(String id) =>
      _contacts.firstWhere((c) => c.id == id, orElse: () => ContactEntry(
            id: id, name: '—', contactType: ContactType.person, gstRegistered: false)).name;

  String? _glDescription(String id) =>
      _glEntries.firstWhere((g) => g.id == id, orElse: () => GeneralLedgerEntry(
            id: id, label: '—', description: '—', gstApplicable: false,
            direction: GlDirection.moneyIn)).description;


  String _formatCents(int cents) {
    final dollars = cents / 100;
    final str = dollars.toStringAsFixed(2).split('.');
    final buf = StringBuffer();
    int c = 0;
    for (int i = str[0].length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(str[0][i]);
      c++;
    }
    return '\$${buf.toString().split('').reversed.join()}.${str[1]}';
  }

  // ── Validation & save ──────────────────────────────────────────────────────

  Future<void> _save(TransactionFormData data) async {
    if (_isDateLocked(data.date)) {
      _showSnackbar(
          'Cannot create transaction: ${data.date.year}-${data.date.month.toString().padLeft(2, '0')} is locked.');
      return;
    }

    setState(() => _saving = true);
    try {
      String? contactId = data.existingContactId;
      if (contactId == null && data.newContactName != null && data.newContactName!.isNotEmpty) {
        final contactRes = await context.read<ApiClient>().post(
              '/contacts',
              jsonEncode({
                'name': data.newContactName,
                'contactType': 'person',
                'gstRegistered': false,
              }),
            );
        if (!mounted) return;
        if (contactRes.statusCode != 201) {
          String msg = 'Failed to create contact (${contactRes.statusCode})';
          try {
            msg = (jsonDecode(contactRes.body) as Map)['error'] as String? ?? msg;
          } catch (_) {}
          _showSnackbar(msg);
          return;
        }
        contactId = ContactEntry.fromJson(
            jsonDecode(contactRes.body) as Map<String, dynamic>).id;
        // Propagate the new contact to every other screen watching the
        // cache (e.g. the Contacts screen) immediately, not just locally.
        context.read<ReferenceDataCache>().refreshContacts();
      }

      final body = jsonEncode({
        'contactId': contactId,
        'generalLedgerId': data.gl.id,
        'amount': data.amountCents,
        'gstAmount': data.gstCents,
        'transactionType':
            data.gl.direction == GlDirection.moneyOut ? 'debit' : 'credit',
        'receiptNumber': data.receiptNumber,
        'description': data.description,
        'transactionDate':
            '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}-${data.date.day.toString().padLeft(2, '0')}',
        'isCash': data.isCash,
        'bankAccountId': data.bankAccountId,
      });

      final res = await context.read<ApiClient>().post('/transactions', body);
      if (!mounted) return;

      if (res.statusCode == 201) {
        _showSnackbar('Transaction saved');
        setState(() {
          _addingMoneyIn = false;
          _addingMoneyOut = false;
          _viewMonth = DateTime(data.date.year, data.date.month);
        });
        await _load();
      } else {
        String msg = 'Save failed (${res.statusCode})';
        try { msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg; } catch (_) {}
        _showSnackbar(msg);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openImport() async {
    final didImport = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportTransactionsScreen(),
      ),
    );
    if (didImport == true) _load();
  }

  Future<void> _openCbaImport() async {
    final didImport = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportCbaScreen(),
      ),
    );
    if (didImport == true) _load();
  }

  Future<void> _openCashflowManagerImport() async {
    final didImport = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportCashflowManagerScreen(),
      ),
    );
    if (didImport == true) _load();
  }

  // ── Inline edit ─────────────────────────────────────────────────────────────

  void _startEdit(TransactionEntry t) =>
      setState(() { _editingId = t.id; _editSaving = false; });

  void _cancelEdit() => setState(() { _editingId = null; _editSaving = false; });

  Future<void> _saveEdit(TransactionFormData data) async {
    if (_isDateLocked(data.date)) {
      _showSnackbar(
          'Cannot update transaction: ${data.date.year}-${data.date.month.toString().padLeft(2, '0')} is locked.');
      return;
    }

    setState(() => _editSaving = true);
    try {
      String? contactId = data.existingContactId;
      if (contactId == null && data.newContactName != null && data.newContactName!.isNotEmpty) {
        final contactRes = await context.read<ApiClient>().post(
              '/contacts',
              jsonEncode({
                'name': data.newContactName,
                'contactType': 'person',
                'gstRegistered': false,
              }),
            );
        if (!mounted) return;
        if (contactRes.statusCode != 201) {
          String msg = 'Failed to create contact (${contactRes.statusCode})';
          try {
            msg = (jsonDecode(contactRes.body) as Map)['error'] as String? ?? msg;
          } catch (_) {}
          _showSnackbar(msg);
          return;
        }
        contactId = ContactEntry.fromJson(
            jsonDecode(contactRes.body) as Map<String, dynamic>).id;
        // Propagate the new contact to every other screen watching the
        // cache (e.g. the Contacts screen) immediately, not just locally.
        context.read<ReferenceDataCache>().refreshContacts();
      }

      final body = jsonEncode({
        'contactId': contactId,
        'generalLedgerId': data.gl.id,
        'amount': data.amountCents,
        'gstAmount': data.gstCents,
        'transactionType':
            data.gl.direction == GlDirection.moneyOut ? 'debit' : 'credit',
        'receiptNumber': data.receiptNumber,
        'description': data.description,
        'transactionDate':
            '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}-${data.date.day.toString().padLeft(2, '0')}',
        'isCash': data.isCash,
        'bankAccountId': data.bankAccountId,
      });

      final res = await context.read<ApiClient>().put('/transactions/$_editingId', body);
      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() => _editingId = null);
        _showSnackbar('Transaction updated');
        await _load();
      } else {
        String msg = 'Update failed (${res.statusCode})';
        try { msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg; } catch (_) {}
        _showSnackbar(msg);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Update failed: $e');
    } finally {
      if (mounted) setState(() => _editSaving = false);
    }
  }

  Future<void> _deleteTransaction(TransactionEntry t) async {
    final parts = t.transactionDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : t.transactionDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'Delete the ${t.isCredit ? 'income' : 'expense'} of '
          '${_formatCents(t.totalAmount)} for '
          '${_contactName(t.contactId) ?? '—'} on $dateLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await context.read<ApiClient>().delete('/transactions/${t.id}');
    if (!mounted) return;
    if (res.statusCode == 204) {
      _showSnackbar('Transaction deleted');
      await _load();
    } else {
      _showSnackbar('Delete failed (${res.statusCode})');
    }
  }

  Future<void> _generateTransactionsPdf() async {
    final txns = _viewMonthTransactions;
    final monthLabel = '${_monthNames[_viewMonth.month]} ${_viewMonth.year}';
    final generated = Formatters.formatDateShort(DateTime.now());
    final contactNames = {for (final c in _contacts) c.id: c.name};
    final glDescriptions = {for (final g in _glEntries) g.id: g.description};

    final doc = pw.Document(title: 'Transactions - $monthLabel');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
      build: (ctx) => [
        PdfReportComponents.entityHeader(_entityDetails),
        ...TransactionsPdfReport.build(
          transactions: txns,
          contactNames: contactNames,
          glDescriptions: glDescriptions,
          periodLabel: monthLabel,
          formatCents: Formatters.formatCents,
        ),
      ],
    ));
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'transactions-$monthLabel.pdf',
    );
  }

  void _generateTransactionsXlsx() {
    final txns = _isGlMode
        ? _searchGlResults
        : _isSearchMode
            ? _searchResults
            : _viewMonthTransactions;
    final moneyIn = txns.where((t) => t.isCredit).toList();
    final moneyOut = txns.where((t) => !t.isCredit).toList();
    final periodLabel = _isGlMode
        ? '${_searchGlPair!.incomeGl.description} $_searchYear'
        : _isSearchMode
            ? '${_searchContact!.name} $_searchYear'
            : '${_monthNames[_viewMonth.month]} ${_viewMonth.year}';

    final excel = xls.Excel.createExcel();
    _writeTransactionSheet(excel, 'Money In', moneyIn);
    _writeTransactionSheet(excel, 'Money Out', moneyOut);
    excel.delete('Sheet1');

    // excel.save() drives the browser download via the package's own
    // web helper, which mis-builds the Blob and corrupts the file
    // (it spreads the bytes into a JS array of numbers instead of a
    // single binary blob part). Encode the bytes ourselves and reuse
    // the working Blob/anchor pattern used for the ABA export above.
    final bytes = excel.encode();
    if (bytes == null) {
      _showSnackbar('Failed to generate Excel file.');
      return;
    }
    final blob = web.Blob(<JSAny>[Uint8List.fromList(bytes).toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = 'transactions-$periodLabel.xlsx'
      ..click();
    web.URL.revokeObjectURL(url);
  }

  void _writeTransactionSheet(
      xls.Excel excel, String sheetName, List<TransactionEntry> txns) {
    final sheet = excel[sheetName];
    sheet.appendRow(<xls.CellValue?>[
      xls.TextCellValue('Date'),
      xls.TextCellValue('Contact'),
      xls.TextCellValue('GL Account'),
      xls.TextCellValue('Description'),
      xls.TextCellValue('Receipt #'),
      xls.TextCellValue('Amount'),
      xls.TextCellValue('GST'),
      xls.TextCellValue('Total'),
      xls.TextCellValue('Reconciled'),
    ]);
    for (final t in txns) {
      sheet.appendRow(<xls.CellValue?>[
        xls.TextCellValue(t.transactionDate),
        xls.TextCellValue(_contactName(t.contactId) ?? '—'),
        xls.TextCellValue(_glDescription(t.generalLedgerId) ?? '—'),
        xls.TextCellValue(t.description),
        xls.TextCellValue(t.receiptNumber),
        xls.DoubleCellValue(t.amount / 100),
        xls.DoubleCellValue(t.gstAmount / 100),
        xls.DoubleCellValue(t.totalAmount / 100),
        xls.TextCellValue(t.bankMatched ? 'Yes' : 'No'),
      ]);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Registers this screen as a listener of the shared cache so it rebuilds
    // whenever contacts/GL accounts change on another screen, even while
    // retained off-screen by the IndexedStack.
    context.watch<ReferenceDataCache>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : _buildContent(),
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

  Widget _buildContent() {
    return _buildMonthSection();
  }

  // ── Month transaction list ─────────────────────────────────────────────────

  Widget _buildMonthSection() {
    final txns = _isGlMode ? _searchGlResults : _isSearchMode ? _searchResults : _viewMonthTransactions;
    final moneyIn = txns.where((t) => t.isCredit).toList();
    final moneyOut = txns.where((t) => !t.isCredit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              if (_isSearchMode || _isGlMode) _buildYearNav() else _buildMonthNav(),
              const Spacer(),
              _buildSearchBar(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download Transactions (Excel)',
                onPressed: _generateTransactionsXlsx,
              ),
              Builder(builder: (context) {
                final canImport = context.watch<AuthState>().isAdmin;
                if (!canImport) return const SizedBox.shrink();
                return MenuAnchor(
                  builder: (context, controller, _) => IconButton(
                    icon: const Icon(Icons.upload_file_outlined),
                    tooltip: 'Import',
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon:
                          const Icon(Icons.table_chart_outlined, size: 18),
                      onPressed: _openImport,
                      child: const Text("Woodgate Men's Shed Spreadsheet"),
                    ),
                    MenuItemButton(
                      leadingIcon:
                          const Icon(Icons.account_balance_outlined, size: 18),
                      onPressed: _openCbaImport,
                      child: const Text('CBA Transactions'),
                    ),
                    MenuItemButton(
                      leadingIcon:
                          const Icon(Icons.receipt_long_outlined, size: 18),
                      onPressed: _openCashflowManagerImport,
                      child: const Text('CashFlow Manager'),
                    ),
                  ],
                );
              }),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Money In'),
            Tab(text: 'Money Out'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionTab(moneyIn, false),
              _buildTransactionTab(moneyOut, true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      width: 320,
      child: Autocomplete<ContactEntry>(
        key: ValueKey(_searchResetKey),
        displayStringForOption: (c) => c.name,
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) return _contacts;
          final q = textEditingValue.text.toLowerCase();
          return _contacts.where((c) => c.name.toLowerCase().contains(q));
        },
        onSelected: (contact) {
          setState(() => _searchContact = contact);
          _tabController.animateTo(1);
        },
        fieldViewBuilder: (context, textController, focusNode, _) {
          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Search by contact',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: (_isSearchMode || _isGlMode)
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _searchContact = null;
                        _searchGlPair = null;
                        _searchResetKey++;
                      }),
                    )
                  : null,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 220, maxWidth: 320),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final c = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(c.name),
                      subtitle: Text(
                          c.contactType == ContactType.company
                              ? 'Company'
                              : 'Person',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => onSelected(c),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearNav() {
    final title = _isGlMode
        ? '${_searchGlPair!.incomeGl.description} — $_searchYear'
        : '${_searchContact!.name} — $_searchYear';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _searchYear--),
          tooltip: 'Previous year',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _searchYear < DateTime.now().year
              ? () => setState(() => _searchYear++)
              : null,
          tooltip: 'Next year',
        ),
      ],
    );
  }

  Widget _buildTransactionTab(List<TransactionEntry> txns, bool isMoneyOut) {
    return SingleChildScrollView(
      child: _buildTransactionList(txns, isMoneyOut),
    );
  }

  Widget _buildMonthNav() {
    final label = '${_monthNames[_viewMonth.month]} ${_viewMonth.year}';
    final monthKey =
        '${_viewMonth.year}-${_viewMonth.month.toString().padLeft(2, '0')}';
    final isLocked = _lockedMonths.contains(monthKey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.headlineMedium),
        if (isLocked) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'This month is locked',
            child: Icon(Icons.lock_outlined,
                size: 18, color: Colors.orange.shade700),
          ),
        ],
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _prevMonth,
          tooltip: 'Previous month',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _canGoForward ? _nextMonth : null,
          tooltip: 'Next month',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Download Transactions PDF',
          onPressed: _generateTransactionsPdf,
        ),
        if (_selectedTransactionIds.isNotEmpty &&
            context.read<AuthState>().isAdmin) ...[
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _handleBankUpload,
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: Text('Bank Upload (${_selectedTransactionIds.length})'),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionList(List<TransactionEntry> txns, bool isMoneyOut) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isMoneyOut && context.read<AuthState>().isAdmin)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: txns.every((t) => _selectedTransactionIds.contains(t.id)),
                      tristate: true,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedTransactionIds.addAll(txns.map((t) => t.id));
                          } else {
                            for (final t in txns) {
                              _selectedTransactionIds.remove(t.id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                SizedBox(width: 90, child: _colHeader('Date', 0)),
                SizedBox(width: 180, child: _colHeader('Contact', 1)),
                SizedBox(width: 150, child: _colHeader('Account', 2)),
                Expanded(child: _colHeader('Description', 3)),
                SizedBox(width: 80, child: _colHeader('Receipt', 4)),
                SizedBox(
                    width: 120,
                    child: _colHeader('Amount', 5,
                        align: MainAxisAlignment.end)),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      'Matched',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Center(
                    child: Text(
                      'Cash',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 110),
              ],
            ),
          ),
          const Divider(height: 1),
          if (txns.isEmpty && !_isSearchMode && !_isGlMode)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Text('No transactions for this month.',
                  style: const TextStyle(color: Colors.black54)),
            ),
          if (txns.isEmpty && _isSearchMode)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Text(
                  'No transactions for ${_searchContact!.name} in $_searchYear.',
                  style: const TextStyle(color: Colors.black54)),
            ),
          if (txns.isEmpty && _isGlMode)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Text(
                  'No transactions for ${_searchGlPair!.incomeGl.description} in $_searchYear.',
                  style: const TextStyle(color: Colors.black54)),
            ),
          ...txns.map((t) => _buildTransactionRow(t, isMoneyOut)),
          _buildAddSection(isMoneyOut),
        ],
      ),
    );
  }

  Widget _buildAddSection(bool isMoneyOut) {
    final bool canEdit = context.read<AuthState>().canEdit;
    if (!canEdit || _isSearchMode || _isGlMode) return const SizedBox.shrink();

    final isAdding = isMoneyOut ? _addingMoneyOut : _addingMoneyIn;

    if (isAdding) {
      return Column(
        children: [
          TransactionForm(
            key: ValueKey(isMoneyOut ? 'add-out' : 'add-in'),
            contacts: _contacts,
            glEntries: _glEntries,
            bankAccounts: _bankAccountSummaries,
            nextMoneyOutReceipt: _formatMoneyOutReceipt(),
            initialDirection:
                isMoneyOut ? GlDirection.moneyOut : GlDirection.moneyIn,
            compact: true,
            isSaving: _saving,
            onSave: _save,
            onCancel: () => setState(() {
              if (isMoneyOut) _addingMoneyOut = false;
              else _addingMoneyIn = false;
            }),
          ),
          const Divider(height: 1),
        ],
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isMoneyOut) _addingMoneyOut = true;
            else _addingMoneyIn = true;
            _saving = false;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                if (isMoneyOut && context.read<AuthState>().isAdmin) const SizedBox(width: 40),
                Icon(Icons.add,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('Add transaction',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildTransactionRow(TransactionEntry t, bool isMoneyOut) {
    if (_editingId == t.id) {
      return Column(
        children: [
          TransactionForm(
            key: ValueKey('edit-${t.id}'),
            contacts: _contacts,
            glEntries: _glEntries,
            bankAccounts: _bankAccountSummaries,
            nextMoneyOutReceipt: _formatMoneyOutReceipt(),
            initial: t,
            compact: true,
            isSaving: _editSaving,
            onSave: _saveEdit,
            onCancel: _cancelEdit,
          ),
          const Divider(height: 1),
        ],
      );
    }

    final parts = t.transactionDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : t.transactionDate;

    final isIncome = t.isCredit;
    final amountText = isIncome
        ? _formatCents(t.totalAmount)
        : '(${_formatCents(t.totalAmount)})';
    final amountColor = isIncome ? Colors.black87 : Colors.red.shade700;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMoneyOut && context.read<AuthState>().isAdmin)
                SizedBox(
                  width: 40,
                  child: t.bankMatched
                      ? null
                      : Checkbox(
                          value: _selectedTransactionIds.contains(t.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedTransactionIds.add(t.id);
                              } else {
                                _selectedTransactionIds.remove(t.id);
                              }
                            });
                          },
                        ),
                ),
              SizedBox(
                width: 90,
                child: Text(dateLabel, style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 180,
                child: Text(
                  _contactName(t.contactId) ?? '—',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 150,
                child: Text(
                  _glDescription(t.generalLedgerId) ?? '—',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  t.description,
                  style: const TextStyle(fontSize: 13),
                  softWrap: true,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(t.receiptNumber,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 13,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 80,
                child: Center(
                  child: Text(
                    t.bankMatched ? 'Y' : 'N',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: t.bankMatched
                          ? Colors.green.shade700
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    t.isCash ? 'Y' : 'N',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: t.isCash
                          ? Colors.blue.shade700
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Builder(
                  builder: (context) {
                    final bool canEdit = context.watch<AuthState>().canEdit;
                    final bool locked = _isTransactionLocked(t);
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          onPressed: () {
                            final contact = _contacts.firstWhere(
                              (c) => c.id == t.contactId,
                              orElse: () => ContactEntry(
                                  id: t.contactId,
                                  name: 'Unknown',
                                  contactType: ContactType.person,
                                  gstRegistered: false),
                            );
                            final gl = _glEntries.firstWhere(
                              (g) => g.id == t.generalLedgerId,
                              orElse: () => GeneralLedgerEntry(
                                  id: t.generalLedgerId,
                                  label: '',
                                  description: 'Unknown',
                                  gstApplicable: false,
                                  direction: GlDirection.moneyIn),
                            );
                            TransactionReceiptPdf.generateAndPrint(
                              transaction: t,
                              entity: _entityDetails,
                              contact: contact,
                              glAccount: gl,
                              formatCents: _formatCents,
                            );
                          },
                          tooltip: 'Print PDF Receipt',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (locked)
                          const Tooltip(
                            message: 'Month is locked',
                            child: Icon(Icons.lock_outlined,
                                size: 14, color: Colors.orange),
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: canEdit ? () => _startEdit(t) : null,
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.error),
                            onPressed: canEdit ? () => _deleteTransaction(t) : null,
                            tooltip: 'Delete',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

}
