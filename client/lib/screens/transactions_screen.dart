import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import 'import_transactions_screen.dart';

/// Entry screen for creating transactions, with a month-view list above the form.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
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

  ContactEntry? _selectedContact;
  String _contactTypedText = '';
  bool _saveNewContact = false;
  int _contactResetKey = 0;
  GeneralLedgerEntry? _selectedGl;
  DateTime _date = DateTime.now();

  final _amountController = TextEditingController();
  final _gstController = TextEditingController();
  final _totalController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _receiptType = 'bankTransfer';
  final _receiptOtherController = TextEditingController();
  final _receiptOutController = TextEditingController();

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
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _gstController.dispose();
    _totalController.dispose();
    _descriptionController.dispose();
    _receiptOtherController.dispose();
    _receiptOutController.dispose();
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
          cmp = a.receiptNumber
              .toLowerCase()
              .compareTo(b.receiptNumber.toLowerCase());
        case 4:
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
      _amountController.clear();
      _gstController.text = (gl?.gstApplicable ?? false) ? '' : '0.00';
      _totalController.clear();
      _receiptType = 'bankTransfer';
      _receiptOtherController.clear();
      _receiptOutController.text =
          gl?.direction == GlDirection.moneyOut ? _formatMoneyOutReceipt() : '';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormSection(),
        const SizedBox(height: 16),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildMonthSection(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Month transaction list ─────────────────────────────────────────────────

  Widget _buildMonthSection() {
    final txns = _viewMonthTransactions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthNav(),
        const SizedBox(height: 12),
        if (txns.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No transactions for this month.',
                style: TextStyle(color: Colors.black54)),
          )
        else
          _buildTransactionList(txns),
      ],
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
                Expanded(child: _colHeader('Account', 2)),
                SizedBox(width: 110, child: _colHeader('Receipt', 3)),
                SizedBox(
                    width: 120,
                    child: _colHeader('Amount', 4,
                        align: MainAxisAlignment.end)),
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
            children: [
              SizedBox(
                width: 90,
                child: Text(dateLabel,
                    style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 180,
                child: Text(
                  _contactName(t.contactId) ?? '—',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _glDescription(t.generalLedgerId) ?? '—',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (t.description.isNotEmpty)
                      Text(
                        t.description,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
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
            ],
          ),
        ),
        const Divider(height: 1),
      ],
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
            OutlinedButton.icon(
              onPressed: _saving ? null : _openImport,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Import'),
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
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'General Ledger Account',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: DropdownButton<GeneralLedgerEntry>(
        value: _selectedGl,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: _glEntries.map((gl) {
          final isIn = gl.direction == GlDirection.moneyIn;
          return DropdownMenuItem(
            value: gl,
            child: Row(
              children: [
                Icon(
                  isIn
                      ? Icons.arrow_circle_down_outlined
                      : Icons.arrow_circle_up_outlined,
                  size: 16,
                  color: isIn ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(gl.description,
                        overflow: TextOverflow.ellipsis)),
                if (gl.gstApplicable) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
        const SizedBox(width: 8),
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
