import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import 'import_cba_screen.dart';
import 'import_transactions_screen.dart';

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
  int _nextMoneyOutSeq = 1;
  int? _sortColumn;
  bool _sortAscending = true;

  late DateTime _viewMonth;

  // ── Contact search / year-view state ───────────────────────────────────────
  ContactEntry? _searchContact;
  int _searchYear = DateTime.now().year;
  int _searchResetKey = 0;

  ContactEntry? _selectedContact;
  String _contactTypedText = '';
  bool _saveNewContact = false;
  int _contactResetKey = 0;
  GeneralLedgerEntry? _selectedGl;
  GlDirection? _selectedDirection;
  DateTime _date = DateTime.now();

  final _amountController = TextEditingController();
  final _gstController = TextEditingController();
  final _totalController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _receiptType = 'bankTransfer';
  final _receiptOtherController = TextEditingController();
  final _receiptOutController = TextEditingController();

  // ── Inline edit state ───────────────────────────────────────────────────────
  String? _editingId;
  bool _editSaving = false;
  DateTime _editDate = DateTime.now();
  String? _editContactId;
  GeneralLedgerEntry? _editGl;
  final _editReceiptController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  final _editAmountController = TextEditingController();
  final _editGstController = TextEditingController();
  final _editTotalController = TextEditingController();

  bool get _editGstApplicable => _editGl?.gstApplicable ?? false;

  bool get _isMoneyOut => _selectedGl?.direction == GlDirection.moneyOut;

  bool get _hasUnmatchedContact =>
      _selectedContact == null && _contactTypedText.trim().isNotEmpty;
  bool get _gstApplicable => _selectedGl?.gstApplicable ?? false;

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
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _gstController.dispose();
    _totalController.dispose();
    _descriptionController.dispose();
    _receiptOtherController.dispose();
    _receiptOutController.dispose();
    _editReceiptController.dispose();
    _editDescriptionController.dispose();
    _editAmountController.dispose();
    _editGstController.dispose();
    _editTotalController.dispose();
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
      ]);

      if (!mounted) return;

      if (results.any((r) => r.statusCode != 200)) {
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

      setState(() {
        _contacts = contacts;
        _glEntries = glEntries;
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

  String? _contactName(String id) =>
      _contacts.firstWhere((c) => c.id == id, orElse: () => ContactEntry(
            id: id, name: '—', contactType: ContactType.person, gstRegistered: false)).name;

  String? _glDescription(String id) =>
      _glEntries.firstWhere((g) => g.id == id, orElse: () => GeneralLedgerEntry(
            id: id, label: '—', description: '—', gstApplicable: false,
            direction: GlDirection.moneyIn)).description;

  // ── GL changed ─────────────────────────────────────────────────────────────

  void _onGlChanged(GeneralLedgerEntry? gl) {
    setState(() {
      _selectedGl = gl;
      _selectedDirection = gl?.direction;
      _amountController.clear();
      _gstController.text = (gl?.gstApplicable ?? false) ? '' : '0.00';
      _totalController.clear();
      _receiptType = 'bankTransfer';
      _receiptOtherController.clear();
      _receiptOutController.text =
          gl?.direction == GlDirection.moneyOut ? _formatMoneyOutReceipt() : '';
    });
  }

  void _onDirectionChanged(GlDirection? dir) {
    setState(() {
      _selectedDirection = dir;
      if (_selectedGl != null && _selectedGl!.direction != dir) {
        _selectedGl = null;
        _amountController.clear();
        _gstController.clear();
        _totalController.clear();
        _receiptType = 'bankTransfer';
        _receiptOtherController.clear();
        _receiptOutController.clear();
      }
    });
  }

  // ── Amount calculation ─────────────────────────────────────────────────────

  void _handleAmountChanged(String value) {
    final amount = _parseAmount(value);
    if (amount == null) {
      _gstController.text = _gstApplicable ? '' : '0.00';
      _totalController.clear();
      return;
    }
    final amountCents = _dollarsToCents(amount);
    if (_gstApplicable) {
      final gstCents = (amountCents / 10).round();
      _gstController.text = _centsToString(gstCents);
      _totalController.text = _centsToString(amountCents + gstCents);
    } else {
      _gstController.text = '0.00';
      _totalController.text = value;
    }
  }

  void _handleTotalChanged(String value) {
    final total = _parseAmount(value);
    if (total == null) {
      _amountController.clear();
      _gstController.text = _gstApplicable ? '' : '0.00';
      return;
    }
    final totalCents = _dollarsToCents(total);
    if (_gstApplicable) {
      final gstCents = (totalCents / 11).round();
      _amountController.text = _centsToString(totalCents - gstCents);
      _gstController.text = _centsToString(gstCents);
    } else {
      _amountController.text = value;
      _gstController.text = '0.00';
    }
  }

  void _handleGstChanged(String value) {
    final amount = _parseAmount(_amountController.text);
    final gst = _parseAmount(value);
    if (amount == null || gst == null) return;
    _totalController.text =
        _centsToString(_dollarsToCents(amount) + _dollarsToCents(gst));
  }

  double? _parseAmount(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int _dollarsToCents(double d) => (d * 100).round();
  String _centsToString(int cents) => (cents / 100).toStringAsFixed(2);

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

  String? _validate() {
    if (_selectedContact == null) {
      if (_contactTypedText.trim().isEmpty) return 'Please enter a contact';
      if (!_saveNewContact) {
        return 'Contact not found — tick "Save to contacts" or select an existing contact';
      }
    }
    if (_selectedGl == null) return 'Please select a general ledger account';
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) return 'Amount must be greater than zero';
    final gst = _parseAmount(_gstController.text);
    if (gst == null || gst < 0) return 'GST amount must be zero or more';
    if (_isMoneyOut) {
      if (_receiptOutController.text.trim().isEmpty) return 'Receipt number is required';
    } else if (_receiptType == 'other') {
      if (!RegExp(r'^\d{7}$').hasMatch(_receiptOtherController.text.trim())) {
        return 'Receipt number must be exactly 7 digits';
      }
    }
    return null;
  }

  String _buildReceiptNumber() {
    if (_isMoneyOut) return _receiptOutController.text.trim();
    switch (_receiptType) {
      case 'square': return 'Square';
      case 'other': return _receiptOtherController.text.trim();
      default: return 'Bank Transfer';
    }
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) { _showSnackbar(error); return; }

    setState(() => _saving = true);
    try {
      // Create contact on-the-fly if checkbox was ticked.
      if (_selectedContact == null && _saveNewContact) {
        final contactRes = await context.read<ApiClient>().post(
              '/contacts',
              jsonEncode({
                'name': _contactTypedText.trim(),
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
        final created = ContactEntry.fromJson(
            jsonDecode(contactRes.body) as Map<String, dynamic>);
        setState(() => _selectedContact = created);
      }

      final body = jsonEncode({
        'contactId': _selectedContact!.id,
        'generalLedgerId': _selectedGl!.id,
        'amount': _dollarsToCents(_parseAmount(_amountController.text)!),
        'gstAmount': _dollarsToCents(_parseAmount(_gstController.text)!),
        'transactionType': _isMoneyOut ? 'debit' : 'credit',
        'receiptNumber': _buildReceiptNumber(),
        'description': _descriptionController.text.trim(),
        'transactionDate':
            '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      });

      final res = await context.read<ApiClient>().post('/transactions', body);
      if (!mounted) return;

      if (res.statusCode == 201) {
        _showSnackbar('Transaction saved');
        _resetForm();
        // Jump view to the month of the saved transaction so it's visible
        setState(() => _viewMonth = DateTime(_date.year, _date.month));
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

  void _resetForm() {
    setState(() {
      _selectedContact = null;
      _contactTypedText = '';
      _saveNewContact = false;
      _contactResetKey++;
      _selectedGl = null;
      _selectedDirection = null;
      _date = DateTime.now();
      _amountController.clear();
      _gstController.clear();
      _totalController.clear();
      _descriptionController.clear();
      _receiptType = 'bankTransfer';
      _receiptOtherController.clear();
      _receiptOutController.clear();
      _saving = false;
    });
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

  void _startEdit(TransactionEntry t) {
    final glMatch = _glEntries.where((g) => g.id == t.generalLedgerId);
    setState(() {
      _editingId = t.id;
      _editSaving = false;
      _editDate = DateTime.parse(t.transactionDate);
      _editContactId = t.contactId;
      _editGl = glMatch.isEmpty ? null : glMatch.first;
      _editReceiptController.text = t.receiptNumber;
      _editDescriptionController.text = t.description;
      _editAmountController.text = _centsToString(t.amount);
      _editGstController.text = _centsToString(t.gstAmount);
      _editTotalController.text = _centsToString(t.totalAmount);
    });
  }

  void _cancelEdit() => setState(() { _editingId = null; _editSaving = false; });

  Future<void> _saveEdit() async {
    if (_editContactId == null) { _showSnackbar('Please select a contact'); return; }
    if (_editGl == null) { _showSnackbar('Please select a GL account'); return; }
    final amount = _parseAmount(_editAmountController.text);
    if (amount == null || amount <= 0) { _showSnackbar('Amount must be greater than zero'); return; }
    final gst = _parseAmount(_editGstController.text);
    if (gst == null || gst < 0) { _showSnackbar('GST must be zero or more'); return; }

    setState(() => _editSaving = true);

    final body = jsonEncode({
      'contactId': _editContactId,
      'generalLedgerId': _editGl!.id,
      'amount': _dollarsToCents(amount),
      'gstAmount': _dollarsToCents(gst),
      'transactionType': _editGl!.direction == GlDirection.moneyOut ? 'debit' : 'credit',
      'receiptNumber': _editReceiptController.text.trim(),
      'description': _editDescriptionController.text.trim(),
      'transactionDate':
          '${_editDate.year}-${_editDate.month.toString().padLeft(2, '0')}-${_editDate.day.toString().padLeft(2, '0')}',
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

  // Amount auto-calc for edit form

  void _handleEditAmountChanged(String value) {
    final amount = _parseAmount(value);
    if (amount == null) {
      _editGstController.text = _editGstApplicable ? '' : '0.00';
      _editTotalController.clear();
      return;
    }
    final amountCents = _dollarsToCents(amount);
    if (_editGstApplicable) {
      final gstCents = (amountCents / 10).round();
      _editGstController.text = _centsToString(gstCents);
      _editTotalController.text = _centsToString(amountCents + gstCents);
    } else {
      _editGstController.text = '0.00';
      _editTotalController.text = value;
    }
  }

  void _handleEditTotalChanged(String value) {
    final total = _parseAmount(value);
    if (total == null) {
      _editAmountController.clear();
      _editGstController.text = _editGstApplicable ? '' : '0.00';
      return;
    }
    final totalCents = _dollarsToCents(total);
    if (_editGstApplicable) {
      final gstCents = (totalCents / 11).round();
      _editAmountController.text = _centsToString(totalCents - gstCents);
      _editGstController.text = _centsToString(gstCents);
    } else {
      _editAmountController.text = value;
      _editGstController.text = '0.00';
    }
  }

  void _handleEditGstChanged(String value) {
    final amount = _parseAmount(_editAmountController.text);
    final gst = _parseAmount(value);
    if (amount == null || gst == null) return;
    _editTotalController.text =
        _centsToString(_dollarsToCents(amount) + _dollarsToCents(gst));
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
    final bool canEdit = context.watch<AuthState>().canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canEdit) ...[
          _buildFormSection(),
          const SizedBox(height: 16),
          const Divider(),
        ],
        Expanded(child: _buildMonthSection()),
      ],
    );
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
          child: _buildSearchBar(),
        ),
        const SizedBox(height: 8),
        if (_isSearchMode) _buildYearNav() else _buildMonthNav(),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
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
              _buildTransactionTab(moneyIn),
              _buildTransactionTab(moneyOut),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
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
      ),
    );
  }

  Widget _buildYearNav() {
    return Row(
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
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildTransactionTab(List<TransactionEntry> txns) {
    if (txns.isEmpty) {
      final message = _isSearchMode
          ? 'No transactions for ${_searchContact!.name} in $_searchYear.'
          : 'No transactions for this month.';
      return Center(
        child: Text(message, style: const TextStyle(color: Colors.black54)),
      );
    }
    return SingleChildScrollView(
      child: _buildTransactionList(txns),
    );
  }

  Widget _buildMonthNav() {
    final label = '${_monthNames[_viewMonth.month]} ${_viewMonth.year}';
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.headlineMedium),
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
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<TransactionEntry> txns) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                SizedBox(width: 90, child: _colHeader('Date', 0)),
                SizedBox(width: 180, child: _colHeader('Contact', 1)),
                SizedBox(width: 150, child: _colHeader('Account', 2)),
                Expanded(child: _colHeader('Description', 3)),
                SizedBox(width: 80, child: _colHeader('Receipt', 4)),
                SizedBox(
                    width: 120,
                    child: _colHeader('Amount', 5,
                        align: MainAxisAlignment.end)),
                const SizedBox(width: 76),
              ],
            ),
          ),
          const Divider(height: 1),
          ...txns.map((t) => _buildTransactionRow(t)),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(TransactionEntry t) {
    if (_editingId == t.id) {
      return Column(
        children: [
          _buildEditingRow(t),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                width: 76,
                child: Builder(
                  builder: (context) {
                    final bool canEdit = context.watch<AuthState>().canEdit;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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

  Widget _buildEditingRow(TransactionEntry t) {
    const inputDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date | Contact | GL Account
          Row(
            children: [
              // Date
              SizedBox(
                width: 140,
                child: InkWell(
                  onTap: _editSaving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _editDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _editDate = picked);
                        },
                  child: InputDecorator(
                    decoration:
                        inputDecoration.copyWith(labelText: 'Date'),
                    child: Text(
                      '${_editDate.day.toString().padLeft(2, '0')}/${_editDate.month.toString().padLeft(2, '0')}/${_editDate.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Contact
              Expanded(
                child: InputDecorator(
                  decoration:
                      inputDecoration.copyWith(labelText: 'Contact'),
                  child: DropdownButton<String>(
                    value: _editContactId,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: _contacts
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: _editSaving
                        ? null
                        : (v) => setState(() => _editContactId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // GL Account
              Expanded(
                child: InputDecorator(
                  decoration:
                      inputDecoration.copyWith(labelText: 'GL Account'),
                  child: DropdownButton<GeneralLedgerEntry>(
                    value: _editGl,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: _glEntries.map((g) {
                      final isIn = g.direction == GlDirection.moneyIn;
                      return DropdownMenuItem(
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
                              child: Text(g.description,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13))),
                        ]),
                      );
                    }).toList(),
                    onChanged: _editSaving
                        ? null
                        : (gl) => setState(() {
                              _editGl = gl;
                              if (gl != null && !gl.gstApplicable) {
                                _editGstController.text = '0.00';
                                final total = _parseAmount(
                                    _editTotalController.text);
                                if (total != null) {
                                  _editAmountController.text =
                                      _editTotalController.text;
                                }
                              }
                            }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Receipt | Description | Amount | GST | Total
          Row(
            children: [
              SizedBox(
                width: 130,
                child: TextFormField(
                  controller: _editReceiptController,
                  enabled: !_editSaving,
                  style: const TextStyle(fontSize: 13),
                  decoration: inputDecoration.copyWith(labelText: 'Receipt'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _editDescriptionController,
                  enabled: !_editSaving,
                  style: const TextStyle(fontSize: 13),
                  decoration:
                      inputDecoration.copyWith(labelText: 'Description'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _editAmountController,
                  enabled: !_editSaving,
                  style: const TextStyle(fontSize: 13),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  onChanged: _handleEditAmountChanged,
                  decoration: inputDecoration.copyWith(
                      labelText: 'Amt ex GST', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _editGstController,
                  enabled: !_editSaving && _editGstApplicable,
                  style: const TextStyle(fontSize: 13),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  onChanged: _handleEditGstChanged,
                  decoration: inputDecoration.copyWith(
                    labelText: 'GST',
                    prefixText: '\$ ',
                    fillColor:
                        _editGstApplicable ? null : Colors.grey.shade100,
                    filled: !_editGstApplicable,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _editTotalController,
                  enabled: !_editSaving,
                  style: const TextStyle(fontSize: 13),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  onChanged: _handleEditTotalChanged,
                  decoration: inputDecoration.copyWith(
                      labelText: 'Total', prefixText: '\$ '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Save / Cancel
          Row(
            children: [
              OutlinedButton(
                onPressed: _editSaving ? null : _cancelEdit,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _editSaving ? null : _saveEdit,
                child: _editSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── New transaction form ───────────────────────────────────────────────────

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('New Transaction',
                style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            MenuAnchor(
              builder: (context, controller, _) => OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Import'),
              ),
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.table_chart_outlined, size: 18),
                  onPressed: _saving ? null : _openImport,
                  child: const Text("Woodgate Men's Shed Spreadsheet"),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.account_balance_outlined, size: 18),
                  onPressed: _saving ? null : _openCbaImport,
                  child: const Text('CBA Transactions'),
                ),
              ],
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _saving ? null : _resetForm,
              child: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildForm(),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 180, child: _buildDateField()),
            const SizedBox(width: 16),
            Expanded(child: _buildContactField()),
          ],
        ),
        const SizedBox(height: 16),
        _buildGlField(),
        const SizedBox(height: 16),
        _buildDescriptionField(),
        const SizedBox(height: 16),
        _buildAmountsRow(),
        const SizedBox(height: 16),
        if (_selectedGl != null) _buildReceiptSection(),
      ],
    );
  }

  Widget _buildDateField() {
    final d = _date;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return InkWell(
      onTap: _saving
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _date = picked);
            },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today, size: 18),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildContactField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<ContactEntry>(
          key: ValueKey(_contactResetKey),
          displayStringForOption: (c) => c.name,
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return _contacts;
            final q = textEditingValue.text.toLowerCase();
            return _contacts.where((c) => c.name.toLowerCase().contains(q));
          },
          onSelected: (contact) => setState(() {
            _selectedContact = contact;
            _contactTypedText = contact.name;
            _saveNewContact = false;
          }),
          fieldViewBuilder: (context, textController, focusNode, _) {
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              enabled: !_saving,
              onChanged: (value) {
                setState(() {
                  _contactTypedText = value;
                  if (_selectedContact != null &&
                      value != _selectedContact!.name) {
                    _selectedContact = null;
                  }
                  if (value.trim().isEmpty) _saveNewContact = false;
                });
              },
              decoration: InputDecoration(
                labelText: 'Contact',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                suffixIcon: _selectedContact != null
                    ? const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 18)
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
                      const BoxConstraints(maxHeight: 220, maxWidth: 400),
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
        if (_hasUnmatchedContact)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _saveNewContact,
            onChanged: _saving
                ? null
                : (v) => setState(() => _saveNewContact = v ?? false),
            title: Text(
              'Save "${_contactTypedText.trim()}" to contacts',
              style: const TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    );
  }

  Widget _buildGlField() {
    const decoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );

    final filteredGls = _selectedDirection == null
        ? _glEntries
        : _glEntries.where((g) => g.direction == _selectedDirection).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: InputDecorator(
            decoration: decoration.copyWith(labelText: 'Direction'),
            child: DropdownButton<GlDirection>(
              value: _selectedDirection,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox.shrink(),
              hint: const Text('All', style: TextStyle(fontSize: 13)),
              items: [
                DropdownMenuItem(
                  value: GlDirection.moneyIn,
                  child: Row(children: [
                    Icon(Icons.arrow_circle_down_outlined,
                        size: 15, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    const Text('Money-In', style: TextStyle(fontSize: 13)),
                  ]),
                ),
                DropdownMenuItem(
                  value: GlDirection.moneyOut,
                  child: Row(children: [
                    Icon(Icons.arrow_circle_up_outlined,
                        size: 15, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    const Text('Money-Out', style: TextStyle(fontSize: 13)),
                  ]),
                ),
              ],
              onChanged: _saving ? null : _onDirectionChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InputDecorator(
            decoration: decoration.copyWith(labelText: 'General Ledger Account'),
            child: DropdownButton<GeneralLedgerEntry>(
              value: _selectedGl,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: filteredGls.map((gl) {
                final glIsIn = gl.direction == GlDirection.moneyIn;
                return DropdownMenuItem(
                  value: gl,
                  child: Row(
                    children: [
                      Icon(
                        glIsIn
                            ? Icons.arrow_circle_down_outlined
                            : Icons.arrow_circle_up_outlined,
                        size: 16,
                        color: glIsIn
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(gl.description,
                              overflow: TextOverflow.ellipsis)),
                      if (gl.gstApplicable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text('GST',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.blue.shade700)),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: _saving ? null : _onGlChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      enabled: !_saving,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      ),
    );
  }

  Widget _buildAmountsRow() {
    const decoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      prefixText: '\$ ',
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _totalController,
            enabled: !_saving && _selectedGl != null,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            onChanged: _handleTotalChanged,
            decoration: decoration.copyWith(labelText: 'Total Amount'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _amountController,
            enabled: !_saving && _selectedGl != null,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            onChanged: _handleAmountChanged,
            decoration: decoration.copyWith(labelText: 'Amount (ex GST)'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _gstController,
            enabled: !_saving && _selectedGl != null && _gstApplicable,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            onChanged: _handleGstChanged,
            decoration: decoration.copyWith(
              labelText: 'GST',
              fillColor: _gstApplicable ? null : Colors.grey.shade100,
              filled: !_gstApplicable,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt Number', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (_isMoneyOut) _buildMoneyOutReceipt() else _buildMoneyInReceipt(),
      ],
    );
  }

  Widget _buildMoneyOutReceipt() {
    return SizedBox(
      width: 200,
      child: TextFormField(
        controller: _receiptOutController,
        enabled: !_saving,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          helperText: 'Auto-generated — edit if needed',
        ),
      ),
    );
  }

  Widget _buildMoneyInReceipt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Bank Transfer'),
              selected: _receiptType == 'bankTransfer',
              onSelected: _saving
                  ? null
                  : (_) => setState(() {
                        _receiptType = 'bankTransfer';
                        _receiptOtherController.clear();
                      }),
            ),
            ChoiceChip(
              label: const Text('Square'),
              selected: _receiptType == 'square',
              onSelected: _saving
                  ? null
                  : (_) => setState(() {
                        _receiptType = 'square';
                        _receiptOtherController.clear();
                      }),
            ),
            ChoiceChip(
              label: const Text('Other'),
              selected: _receiptType == 'other',
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _receiptType = 'other'),
            ),
          ],
        ),
        if (_receiptType == 'other') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: TextFormField(
              controller: _receiptOtherController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: const InputDecoration(
                labelText: '7-digit number',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                counterText: '',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
