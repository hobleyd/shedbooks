import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';

/// Validated form data passed to the parent's save handler.
class TransactionFormData {
  final DateTime date;
  final String? existingContactId;
  final String? newContactName;
  final bool saveNewContact;
  final GeneralLedgerEntry gl;
  final int amountCents;
  final int gstCents;
  final String receiptNumber;
  final String description;
  final bool isCash;

  const TransactionFormData({
    required this.date,
    this.existingContactId,
    this.newContactName,
    this.saveNewContact = false,
    required this.gl,
    required this.amountCents,
    required this.gstCents,
    required this.receiptNumber,
    required this.description,
    this.isCash = false,
  });
}

/// Shared transaction form for both new-transaction and inline-edit modes.
///
/// [compact] false → full layout, no buttons (parent controls save via [GlobalKey]).
/// [compact] true  → inline layout with Save/Cancel buttons.
///
/// Call [TransactionFormState.submit] or [TransactionFormState.reset] via
/// a [GlobalKey<TransactionFormState>] when [compact] is false.
class TransactionForm extends StatefulWidget {
  final List<ContactEntry> contacts;
  final List<GeneralLedgerEntry> glEntries;
  final String nextMoneyOutReceipt;
  final TransactionEntry? initial;
  final GlDirection? initialDirection;
  final bool compact;
  final bool isSaving;
  final void Function(TransactionFormData) onSave;
  final VoidCallback? onCancel;

  const TransactionForm({
    super.key,
    required this.contacts,
    required this.glEntries,
    required this.nextMoneyOutReceipt,
    this.initial,
    this.initialDirection,
    required this.compact,
    required this.isSaving,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<TransactionForm> createState() => TransactionFormState();
}

class TransactionFormState extends State<TransactionForm> {
  late DateTime _date;

  // Full (new) mode contact
  ContactEntry? _selectedContact;
  String _contactTypedText = '';
  bool _saveNewContact = false;
  int _contactResetKey = 0;

  // Compact (edit) mode contact
  String? _editContactId;

  GeneralLedgerEntry? _selectedGl;
  GlDirection? _selectedDirection;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isCash = false;
  String _paymentType = 'bankTransfer';
  final TextEditingController _cashReceiptController = TextEditingController();
  final TextEditingController _receiptOutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _date = DateTime.parse(t.transactionDate);
      _editContactId = t.contactId;
      final glMatches = widget.glEntries.where((g) => g.id == t.generalLedgerId);
      _selectedGl = glMatches.isEmpty ? null : glMatches.first;
      _amountController.text = _centsToString(t.amount);
      _gstController.text = _centsToString(t.gstAmount);
      _totalController.text = _centsToString(t.totalAmount);
      _descriptionController.text = t.description;
      if (_selectedGl?.direction == GlDirection.moneyOut) {
        _receiptOutController.text = t.receiptNumber;
      } else {
        switch (t.receiptNumber) {
          case 'Bank Transfer':
            _isCash = false;
            _paymentType = 'bankTransfer';
          case 'Square':
            _isCash = false;
            _paymentType = 'square';
          default:
            _isCash = t.isCash;
            _cashReceiptController.text = t.receiptNumber;
        }
      }
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _gstController.dispose();
    _totalController.dispose();
    _descriptionController.dispose();
    _cashReceiptController.dispose();
    _receiptOutController.dispose();
    super.dispose();
  }

  bool get _isMoneyOut {
    if (_selectedGl != null) return _selectedGl!.direction == GlDirection.moneyOut;
    if (widget.compact) {
      if (widget.initial != null) return !widget.initial!.isCredit;
      return widget.initialDirection == GlDirection.moneyOut;
    }
    return false;
  }

  bool get _gstApplicable => _selectedGl?.gstApplicable ?? false;

  bool get _hasUnmatchedContact =>
      _selectedContact == null && _contactTypedText.trim().isNotEmpty;

  // ── Public API ─────────────────────────────────────────────────────────────

  void reset() {
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
      _isCash = false;
      _paymentType = 'bankTransfer';
      _cashReceiptController.clear();
      _receiptOutController.clear();
    });
  }

  void submit() {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final amount = _parseAmount(_amountController.text)!;
    final gst = _parseAmount(_gstController.text)!;
    widget.onSave(TransactionFormData(
      date: _date,
      existingContactId: widget.compact ? _editContactId : _selectedContact?.id,
      newContactName: !widget.compact && _selectedContact == null
          ? _contactTypedText.trim()
          : null,
      saveNewContact: !widget.compact && _saveNewContact,
      gl: _selectedGl!,
      amountCents: _dollarsToCents(amount),
      gstCents: _dollarsToCents(gst),
      receiptNumber: _buildReceiptNumber(),
      description: _descriptionController.text.trim(),
      isCash: !_isMoneyOut && _isCash,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _validate() {
    if (widget.compact) {
      if (_editContactId == null) return 'Please select a contact';
    } else {
      if (_selectedContact == null) {
        if (_contactTypedText.trim().isEmpty) return 'Please enter a contact';
        if (!_saveNewContact) {
          return 'Contact not found — tick "Save to contacts" or select an existing contact';
        }
      }
    }
    if (_selectedGl == null) return 'Please select a general ledger account';
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) return 'Amount must be greater than zero';
    final gst = _parseAmount(_gstController.text);
    if (gst == null || gst < 0) return 'GST amount must be zero or more';
    if (_isMoneyOut) {
      if (_receiptOutController.text.trim().isEmpty) return 'Receipt number is required';
    } else if (_isCash) {
      if (_cashReceiptController.text.trim().isEmpty) {
        return 'Receipt number is required for cash transactions';
      }
    }
    return null;
  }

  String _buildReceiptNumber() {
    if (_isMoneyOut) return _receiptOutController.text.trim();
    if (_isCash) return _cashReceiptController.text.trim();
    return _paymentType == 'square' ? 'Square' : 'Bank Transfer';
  }

  double? _parseAmount(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int _dollarsToCents(double d) => (d * 100).round();
  String _centsToString(int cents) => (cents / 100).toStringAsFixed(2);

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

  void _onGlChangedFull(GeneralLedgerEntry? gl) {
    setState(() {
      _selectedGl = gl;
      _selectedDirection = gl?.direction;
      _amountController.clear();
      _gstController.text = (gl?.gstApplicable ?? false) ? '' : '0.00';
      _totalController.clear();
      _isCash = false;
      _paymentType = 'bankTransfer';
      _cashReceiptController.clear();
      _receiptOutController.text =
          gl?.direction == GlDirection.moneyOut ? widget.nextMoneyOutReceipt : '';
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
        _isCash = false;
        _paymentType = 'bankTransfer';
        _cashReceiptController.clear();
        _receiptOutController.clear();
      }
    });
  }

  void _onGlChangedCompact(GeneralLedgerEntry? gl) {
    setState(() {
      _selectedGl = gl;
      if (gl != null && !gl.gstApplicable) {
        _gstController.text = '0.00';
        final total = _parseAmount(_totalController.text);
        if (total != null) _amountController.text = _totalController.text;
      }
      if (gl?.direction == GlDirection.moneyOut &&
          widget.initial == null &&
          _receiptOutController.text.isEmpty) {
        _receiptOutController.text = widget.nextMoneyOutReceipt;
      }
      _isCash = false;
      _paymentType = 'bankTransfer';
      _cashReceiptController.clear();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      widget.compact ? _buildCompactLayout() : _buildFullLayout();

  // ── Full (new transaction) layout ──────────────────────────────────────────

  Widget _buildFullLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 180, child: _buildDateFieldFull()),
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

  Widget _buildDateFieldFull() {
    final d = _date;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return InkWell(
      onTap: widget.isSaving
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
            if (textEditingValue.text.isEmpty) return widget.contacts;
            final q = textEditingValue.text.toLowerCase();
            return widget.contacts.where((c) => c.name.toLowerCase().contains(q));
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
              enabled: !widget.isSaving,
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
            onChanged: widget.isSaving
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
        ? widget.glEntries
        : widget.glEntries
            .where((g) => g.direction == _selectedDirection)
            .toList();

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
              onChanged: widget.isSaving ? null : _onDirectionChanged,
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
                          child: Text(buildGlPath(widget.glEntries, gl.id),
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
              onChanged: widget.isSaving ? null : _onGlChangedFull,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      enabled: !widget.isSaving,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  Widget _buildAmountsRow() {
    const decoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      prefixText: '\$ ',
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _totalController,
            enabled: !widget.isSaving && _selectedGl != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            enabled: !widget.isSaving && _selectedGl != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            enabled: !widget.isSaving && _selectedGl != null && _gstApplicable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        enabled: !widget.isSaving,
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
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _isCash,
          onChanged: widget.isSaving
              ? null
              : (v) => setState(() {
                    _isCash = v ?? false;
                    _cashReceiptController.clear();
                  }),
          title: const Text('Cash transaction', style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 4),
        if (_isCash)
          SizedBox(
            width: 200,
            child: TextFormField(
              controller: _cashReceiptController,
              enabled: !widget.isSaving,
              decoration: const InputDecoration(
                labelText: 'Receipt Number',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
          )
        else
          SizedBox(
            width: 240,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: DropdownButton<String>(
                value: _paymentType,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                      value: 'bankTransfer',
                      child: Text('Bank Transfer')),
                  DropdownMenuItem(
                      value: 'square', child: Text('Square Payment')),
                ],
                onChanged: widget.isSaving
                    ? null
                    : (v) =>
                        setState(() => _paymentType = v ?? 'bankTransfer'),
              ),
            ),
          ),
      ],
    );
  }

  // ── Compact (inline edit) layout ───────────────────────────────────────────

  Widget _buildCompactLayout() {
    final isMoneyOut = _isMoneyOut;
    const dec = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      floatingLabelBehavior: FloatingLabelBehavior.always,
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
              if (isMoneyOut) const SizedBox(width: 40),
              SizedBox(width: 140, child: _buildDateFieldCompact()),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: dec.copyWith(labelText: 'Contact'),
                  child: DropdownButton<String>(
                    value: _editContactId,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: widget.contacts
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: widget.isSaving
                        ? null
                        : (v) => setState(() => _editContactId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: dec.copyWith(labelText: 'GL Account'),
                  child: DropdownButton<GeneralLedgerEntry>(
                    value: _selectedGl,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: widget.glEntries
                        .where((g) => g.direction ==
                            (isMoneyOut
                                ? GlDirection.moneyOut
                                : GlDirection.moneyIn))
                        .map((g) {
                      final glIsIn = g.direction == GlDirection.moneyIn;
                      return DropdownMenuItem(
                        value: g,
                        child: Row(children: [
                          Icon(
                            glIsIn
                                ? Icons.arrow_circle_down_outlined
                                : Icons.arrow_circle_up_outlined,
                            size: 14,
                            color: glIsIn
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(buildGlPath(widget.glEntries, g.id),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13))),
                        ]),
                      );
                    }).toList(),
                    onChanged: widget.isSaving ? null : _onGlChangedCompact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Receipt | Description | Total | Amt ex GST | GST
          //        (Money-In: Cash checkbox | Payment/Receipt | Description | ...)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMoneyOut) ...[
                const SizedBox(width: 40),
                _buildCompactReceiptField(dec),
              ] else ...[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _isCash,
                    onChanged: widget.isSaving
                        ? null
                        : (v) => setState(() {
                              _isCash = v ?? false;
                              _cashReceiptController.clear();
                            }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Cash', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: _isCash
                      ? TextFormField(
                          controller: _cashReceiptController,
                          enabled: !widget.isSaving,
                          style: const TextStyle(fontSize: 13),
                          decoration: dec.copyWith(labelText: 'Receipt No.'),
                        )
                      : InputDecorator(
                          decoration: dec.copyWith(labelText: 'Payment'),
                          child: DropdownButton<String>(
                            value: _paymentType,
                            isExpanded: true,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'bankTransfer',
                                  child: Text('Bank Transfer',
                                      style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(
                                  value: 'square',
                                  child: Text('Square Payment',
                                      style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: widget.isSaving
                                ? null
                                : (v) => setState(
                                    () => _paymentType = v ?? 'bankTransfer'),
                          ),
                        ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _descriptionController,
                  enabled: !widget.isSaving,
                  style: const TextStyle(fontSize: 13),
                  decoration: dec.copyWith(labelText: 'Description'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _totalController,
                  enabled: !widget.isSaving,
                  style: const TextStyle(fontSize: 13),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  onChanged: _handleTotalChanged,
                  decoration:
                      dec.copyWith(labelText: 'Total', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _amountController,
                  enabled: !widget.isSaving,
                  style: const TextStyle(fontSize: 13),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  onChanged: _handleAmountChanged,
                  decoration: dec.copyWith(
                      labelText: 'Amt ex GST', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _gstController,
                  enabled: !widget.isSaving && _gstApplicable,
                  style: const TextStyle(fontSize: 13),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  onChanged: _handleGstChanged,
                  decoration: dec.copyWith(
                    labelText: 'GST',
                    prefixText: '\$ ',
                    fillColor: _gstApplicable ? null : Colors.grey.shade100,
                    filled: !_gstApplicable,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Save / Cancel
          Row(
            children: [
              if (isMoneyOut) const SizedBox(width: 40),
              OutlinedButton(
                onPressed: widget.isSaving ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: widget.isSaving ? null : submit,
                child: widget.isSaving
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

  Widget _buildDateFieldCompact() {
    const dec = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
    return InkWell(
      onTap: widget.isSaving
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
        decoration: dec.copyWith(labelText: 'Date'),
        child: Text(
          '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildCompactReceiptField(InputDecoration dec) {
    return SizedBox(
      width: 130,
      child: TextFormField(
        controller: _receiptOutController,
        enabled: !widget.isSaving,
        style: const TextStyle(fontSize: 13),
        decoration: dec.copyWith(labelText: 'Receipt'),
      ),
    );
  }
}
