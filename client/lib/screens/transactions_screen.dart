import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/bank_account_entry.dart';
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/locked_month_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import 'import_cba_screen.dart';
import 'import_transactions_screen.dart';
import '../widgets/transaction_form.dart';
import '../widgets/transaction_receipt_pdf.dart';

/// Entry screen for creating transactions, with a month-view list above the form.
class TransactionsScreen extends StatefulWidget {
  final ContactEntry? initialContact;

  const TransactionsScreen({super.key, this.initialContact});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  List<ContactEntry> _contacts = [];
  List<GeneralLedgerEntry> _glEntries = [];
  List<TransactionEntry> _allTransactions = [];
  List<BankAccountEntry> _bankAccounts = [];
  EntityDetails? _entityDetails;
  Set<String> _lockedMonths = {}; // YYYY-MM values
  int _nextMoneyOutSeq = 1;
  int? _sortColumn;
  bool _sortAscending = true;
  final Set<String> _selectedTransactionIds = {};

  late DateTime _viewMonth;

  // ── Contact search / year-view state ───────────────────────────────────────
  ContactEntry? _searchContact;
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
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
    _load();
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen old) {
    super.didUpdateWidget(old);
    // With state retention, the existing State is reused when the user
    // re-navigates to /transactions. If a different contact arrives via
    // `extra`, switch the search filter to that contact and jump to the
    // Money Out tab (matching initState's behaviour). Reference data is
    // already loaded, so no reload is needed.
    final newContact = widget.initialContact;
    if (newContact != null && newContact.id != old.initialContact?.id) {
      setState(() {
        _searchContact = newContact;
        _searchYear = DateTime.now().year;
        _tabController.index = 1;
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
      final results = await Future.wait([
        client.get('/contacts'),
        client.get('/general-ledger'),
        client.get('/transactions'),
        client.get('/locked-months'),
        client.get('/bank-accounts'),
        client.get('/entity-details'),
      ]);

      if (!mounted) return;

      if (results.take(3).any((r) => r.statusCode != 200)) {
        setState(() {
          _loadError = 'Failed to load reference data';
          _loading = false;
        });
        return;
      }

      final contacts = (jsonDecode(results[0].body) as List)
          .map((e) => ContactEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final glEntries = (jsonDecode(results[1].body) as List)
          .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.description.compareTo(b.description));

      final transactions = (jsonDecode(results[2].body) as List)
          .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

      final bankAccounts = results[4].statusCode == 200
          ? (jsonDecode(results[4].body) as List)
              .map((e) => BankAccountEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : <BankAccountEntry>[];

      // A month is locked only when every bank account has it locked.
      Set<String> lockedMonths = {};
      if (results[3].statusCode == 200 && bankAccounts.isNotEmpty) {
        final allLocked = (jsonDecode(results[3].body) as List)
            .map((e) => LockedMonthEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        final Map<String, Set<String>> accountsByMonth = {};
        for (final entry in allLocked) {
          accountsByMonth.putIfAbsent(entry.monthYear, () => {}).add(entry.bankAccountId);
        }
        lockedMonths = accountsByMonth.entries
            .where((e) => e.value.length >= bankAccounts.length)
            .map((e) => e.key)
            .toSet();
      }

      final entityDetails = results[5].statusCode == 200
          ? EntityDetails.fromJson(jsonDecode(results[5].body) as Map<String, dynamic>)
          : null;

      setState(() {
        _contacts = contacts;
        _glEntries = glEntries;
        _allTransactions = transactions;
        _bankAccounts = bankAccounts;
        _entityDetails = entityDetails;
        _lockedMonths = lockedMonths;
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
      final abaContent = _generateAba(selectedTxns, senderAccount, sequence);
      final bytes = utf8.encode(abaContent);
      final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final seq = sequence.toString().padLeft(3, '0');
      (web.document.createElement('a') as web.HTMLAnchorElement)
        ..href = url
        ..download = 'WMS${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$seq.aba'
        ..click();
      web.URL.revokeObjectURL(url);

      _showSnackbar('ABA file generated.');
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

  List<TransactionEntry> get _searchResults => _allTransactions
      .where((t) =>
          t.contactId == _searchContact!.id &&
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
          setState(() => _saving = false);
          return;
        }
        contactId = ContactEntry.fromJson(
            jsonDecode(contactRes.body) as Map<String, dynamic>).id;
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
        if (data.isCash) 'isCash': true,
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
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) { setState(() => _saving = false); _showSnackbar('Save failed: $e'); }
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
        setState(() => _editSaving = false);
        return;
      }
      contactId = ContactEntry.fromJson(
          jsonDecode(contactRes.body) as Map<String, dynamic>).id;
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
      if (data.isCash) 'isCash': true,
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
      setState(() => _editSaving = false);
      _showSnackbar(msg);
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

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
    final txns = _isSearchMode ? _searchResults : _viewMonthTransactions;
    final moneyIn = txns.where((t) => t.isCredit).toList();
    final moneyOut = txns.where((t) => !t.isCredit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              if (_isSearchMode) _buildYearNav() else _buildMonthNav(),
              const Spacer(),
              _buildSearchBar(),
              const SizedBox(width: 8),
              Builder(builder: (context) {
                final canEdit = context.watch<AuthState>().canEdit;
                if (!canEdit) return const SizedBox.shrink();
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
              suffixIcon: _isSearchMode
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _searchContact = null;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_searchContact!.name} — $_searchYear',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
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
          if (txns.isEmpty && !(_isSearchMode))
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
          ...txns.map((t) => _buildTransactionRow(t, isMoneyOut)),
          _buildAddSection(isMoneyOut),
        ],
      ),
    );
  }

  Widget _buildAddSection(bool isMoneyOut) {
    final bool canEdit = context.read<AuthState>().canEdit;
    if (!canEdit || _isSearchMode) return const SizedBox.shrink();

    final isAdding = isMoneyOut ? _addingMoneyOut : _addingMoneyIn;

    if (isAdding) {
      return Column(
        children: [
          TransactionForm(
            key: ValueKey(isMoneyOut ? 'add-out' : 'add-in'),
            contacts: _contacts,
            glEntries: _glEntries,
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
                            TransactionReceiptPdf.generateAndDownload(
                              transaction: t,
                              entity: _entityDetails,
                              contact: contact,
                              glAccount: gl,
                              formatCents: _formatCents,
                            );
                          },
                          tooltip: 'Download PDF Receipt',
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
