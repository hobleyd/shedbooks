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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bank_account_summary.dart';
import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import 'gl_account_dropdown.dart';

enum _AmountAnchor { total, amount }

/// Validated form data passed to the parent's save handler.
class TransactionFormData {
  final DateTime date;
  final String? existingContactId;
  final String? newContactName;
  final GeneralLedgerEntry gl;
  final int amountCents;
  final int gstCents;
  final String receiptNumber;
  final String description;
  final bool isCash;
  final String? bankAccountId;

  const TransactionFormData({
    required this.date,
    this.existingContactId,
    this.newContactName,
    required this.gl,
    required this.amountCents,
    required this.gstCents,
    required this.receiptNumber,
    required this.description,
    this.isCash = false,
    this.bankAccountId,
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
  final List<BankAccountSummary> bankAccounts;
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
    this.bankAccounts = const [],
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

  ContactEntry? _selectedContact;
  String _contactTypedText = '';
  int _contactResetKey = 0;

  GeneralLedgerEntry? _selectedGl;
  GlDirection? _selectedDirection;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  /// Which of Total / Amount-ex-GST the user last edited directly.
  /// When GST is then edited, the *other* one is recalculated so the field
  /// the user just set is preserved.
  _AmountAnchor _anchor = _AmountAnchor.total;

  /// The account (or the entity's system Cash account) this transaction
  /// relates to. Null means "not yet chosen" — only auto-defaulted when
  /// there is exactly one non-cash account, otherwise the user must pick.
  String? _selectedBankAccountId;
  final TextEditingController _cashReceiptController = TextEditingController();
  final TextEditingController _receiptOutController = TextEditingController();

  String? get _cashAccountId =>
      widget.bankAccounts.where((a) => a.isCash).map((a) => a.id).firstOrNull;

  /// The single non-cash bank account, when there's exactly one — the only
  /// case where defaulting the account selection is unambiguous.
  String? get _singleNonCashAccountId {
    final nonCash = widget.bankAccounts.where((a) => !a.isCash).toList();
    return nonCash.length == 1 ? nonCash.first.id : null;
  }

  bool get _isCash =>
      _selectedBankAccountId != null &&
      _selectedBankAccountId == _cashAccountId;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _date = DateTime.parse(t.transactionDate);
      final contactMatches = widget.contacts.where((c) => c.id == t.contactId);
      _selectedContact = contactMatches.isEmpty ? null : contactMatches.first;
      _contactTypedText = _selectedContact?.name ?? '';
      final glMatches =
          widget.glEntries.where((g) => g.id == t.generalLedgerId);
      _selectedGl = glMatches.isEmpty ? null : glMatches.first;
      _amountController.text = _centsToString(t.amount);
      _gstController.text = _centsToString(t.gstAmount);
      _totalController.text = _centsToString(t.totalAmount);
      _descriptionController.text = t.description;
      _selectedBankAccountId = t.bankAccountId ??
          (t.isCash ? _cashAccountId : _singleNonCashAccountId);
      if (_selectedGl?.direction == GlDirection.moneyOut) {
        if (t.isCash) {
          _cashReceiptController.text = t.receiptNumber;
        } else {
          _receiptOutController.text = t.receiptNumber;
        }
      } else if (t.isCash) {
        _cashReceiptController.text = t.receiptNumber;
      }
    } else {
      _date = DateTime.now();
      _receiptOutController.text = widget.nextMoneyOutReceipt;
      _selectedBankAccountId = _singleNonCashAccountId;
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
    if (_selectedGl != null)
      return _selectedGl!.direction == GlDirection.moneyOut;
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
      _contactResetKey++;
      _selectedGl = null;
      _selectedDirection = null;
      _date = DateTime.now();
      _amountController.clear();
      _gstController.clear();
      _totalController.clear();
      _descriptionController.clear();
      _selectedBankAccountId = _singleNonCashAccountId;
      _cashReceiptController.clear();
      _receiptOutController.clear();
      _anchor = _AmountAnchor.total;
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
      existingContactId: _selectedContact?.id,
      newContactName:
          _selectedContact == null && _contactTypedText.trim().isNotEmpty
              ? _contactTypedText.trim()
              : null,
      gl: _selectedGl!,
      amountCents: _dollarsToCents(amount),
      gstCents: _dollarsToCents(gst),
      receiptNumber: _buildReceiptNumber(),
      description: _descriptionController.text.trim(),
      isCash: _isCash,
      bankAccountId: _selectedBankAccountId,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _validate() {
    if (_selectedContact == null && _contactTypedText.trim().isEmpty) {
      return 'Please enter a contact';
    }
    if (_selectedGl == null) return 'Please select a general ledger account';
    if (_selectedBankAccountId == null) return 'Please select an account';
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0)
      return 'Amount must be greater than zero';
    final gst = _parseAmount(_gstController.text);
    if (gst == null || gst < 0) return 'GST amount must be zero or more';
    if (_isMoneyOut) {
      if (_isCash) {
        if (_cashReceiptController.text.trim().isEmpty) {
          return 'Receipt number is required for cash transactions';
        }
      } else {
        if (_receiptOutController.text.trim().isEmpty)
          return 'Receipt number is required';
      }
    } else if (_isCash) {
      if (_cashReceiptController.text.trim().isEmpty) {
        return 'Receipt number is required for cash transactions';
      }
    }
    return null;
  }

  String _buildReceiptNumber() {
    if (_isMoneyOut) {
      return _isCash
          ? _cashReceiptController.text.trim()
          : _receiptOutController.text.trim();
    }
    if (_isCash) return _cashReceiptController.text.trim();
    return 'Bank Transfer';
  }

  double? _parseAmount(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int _dollarsToCents(double d) => (d * 100).round();
  String _centsToString(int cents) => (cents / 100).toStringAsFixed(2);

  void _handleAmountChanged(String value) {
    _anchor = _AmountAnchor.amount;
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
    _anchor = _AmountAnchor.total;
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

  /// Recalculates whichever of Total / Amount-ex-GST was *not* last edited
  /// directly by the user, so the field they just set is preserved.
  void _handleGstChanged(String value) {
    final gst = _parseAmount(value);
    if (gst == null) return;
    final gstCents = _dollarsToCents(gst);
    if (_anchor == _AmountAnchor.total) {
      final total = _parseAmount(_totalController.text);
      if (total == null) return;
      _amountController.text =
          _centsToString(_dollarsToCents(total) - gstCents);
    } else {
      final amount = _parseAmount(_amountController.text);
      if (amount == null) return;
      _totalController.text =
          _centsToString(_dollarsToCents(amount) + gstCents);
    }
  }

  void _onGlChangedFull(GeneralLedgerEntry? gl) {
    setState(() {
      _selectedGl = gl;
      _selectedDirection = gl?.direction;
      _amountController.clear();
      _gstController.text = (gl?.gstApplicable ?? false) ? '' : '0.00';
      _totalController.clear();
      _receiptOutController.text = gl?.direction == GlDirection.moneyOut
          ? widget.nextMoneyOutReceipt
          : '';
      _anchor = _AmountAnchor.total;
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
        _receiptOutController.clear();
        _anchor = _AmountAnchor.total;
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
    });
  }

  /// On Money-Out, cash and non-cash accounts show different receipt fields
  /// ([_cashReceiptController] vs [_receiptOutController]) for what is
  /// conceptually the same field, so switching between them swaps which
  /// one is visible — carry the already-typed text across so it doesn't
  /// appear to vanish. [_receiptOutController] is unrelated on Money-In
  /// (it's pre-filled with the next Money-Out receipt number regardless of
  /// direction, ready for if the GL account picked turns out to be
  /// Money-Out) so this carry-over must not run there.
  void _onBankAccountChanged(String? id) {
    setState(() {
      final wasCash = _isCash;
      _selectedBankAccountId = id;
      final isCashNow = _isCash;
      if (_isMoneyOut && wasCash != isCashNow) {
        if (isCashNow && _cashReceiptController.text.isEmpty) {
          _cashReceiptController.text = _receiptOutController.text;
        } else if (!isCashNow && _receiptOutController.text.isEmpty) {
          _receiptOutController.text = _cashReceiptController.text;
        }
      }
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

  Widget _buildContactField(
      {InputDecoration? decoration, bool stretch = false}) {
    final fieldDecoration = (decoration ??
            const InputDecoration(
              labelText: 'Contact',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            ))
        .copyWith(
      suffixIcon: _selectedContact != null
          ? const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 18)
          : null,
    );

    final autocomplete = Autocomplete<ContactEntry>(
      key: ValueKey(_contactResetKey),
      initialValue: _contactTypedText.isNotEmpty
          ? TextEditingValue(text: _contactTypedText)
          : null,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return widget.contacts;
        final q = textEditingValue.text.toLowerCase();
        return widget.contacts.where((c) => c.name.toLowerCase().contains(q));
      },
      onSelected: (contact) => setState(() {
        _selectedContact = contact;
        _contactTypedText = contact.name;
      }),
      fieldViewBuilder: (context, textController, focusNode, _) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          enabled: !widget.isSaving,
          expands: stretch,
          maxLines: stretch ? null : 1,
          textAlignVertical: stretch ? TextAlignVertical.center : null,
          onChanged: (value) {
            setState(() {
              _contactTypedText = value;
              if (_selectedContact != null && value != _selectedContact!.name) {
                _selectedContact = null;
              }
            });
          },
          decoration: fieldDecoration,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // In the compact layout the Row stretches this Column to match
        // whichever sibling field is tallest; Expanded passes that extra
        // height on to the actual input so its visible border fills the
        // allocated space instead of leaving blank room below it. The full
        // layout gives this Column an unbounded height, where Expanded would
        // crash, so only opt in when the caller says it's safe to.
        stretch ? Expanded(child: autocomplete) : autocomplete,
        if (_hasUnmatchedContact)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              '"${_contactTypedText.trim()}" will be added to contacts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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
          child: GlAccountDropdown(
            allEntries: widget.glEntries,
            value: _selectedGl,
            decoration:
                decoration.copyWith(labelText: 'General Ledger Account'),
            directionFilter: _selectedDirection,
            onChanged: widget.isSaving ? null : _onGlChangedFull,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountDropdown(width: 240),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: _isCash
              ? TextFormField(
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
                )
              : TextFormField(
                  controller: _receiptOutController,
                  enabled: !widget.isSaving,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    helperText: 'Auto-generated — edit if needed',
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMoneyInReceipt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountDropdown(width: 240),
        if (_isCash) ...[
          const SizedBox(height: 8),
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
          ),
        ],
      ],
    );
  }

  /// Dropdown of Cash + the entity's bank accounts. Selecting a non-cash
  /// account never shows a receipt number field on Money-In transactions —
  /// the receipt number is set invisibly to "Bank Transfer" on save.
  Widget _buildAccountDropdown({required double width, bool compact = false}) {
    final items = widget.bankAccounts;
    final validValue = items.any((a) => a.id == _selectedBankAccountId)
        ? _selectedBankAccountId
        : null;
    final fontSize = compact ? 12.0 : 13.0;
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Account',
          floatingLabelBehavior: compact ? FloatingLabelBehavior.always : null,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 8 : 8),
        ),
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          isDense: true,
          underline: const SizedBox.shrink(),
          hint: Text('Select account', style: TextStyle(fontSize: fontSize)),
          items: items
              .map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.accountName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: fontSize)),
                  ))
              .toList(),
          onChanged: widget.isSaving ? null : _onBankAccountChanged,
        ),
      ),
    );
  }

  // ── Compact (inline edit) layout ───────────────────────────────────────────

  /// Forces [child] to fill whatever height the ambient stretched Row gives
  /// it. `TextFormField` and a bare `Text` inside `InputDecorator` don't
  /// reliably grow to fill a tight cross-axis constraint from
  /// [CrossAxisAlignment.stretch] on their own — only [Expanded] inside a
  /// bounded [Column] reliably forces it, regardless of the child's own
  /// layout preferences.
  static Widget _stretch(Widget child) =>
      Column(children: [Expanded(child: child)]);

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
          // IntrinsicHeight + stretch lets whichever field naturally needs
          // the most room (GL Account's DropdownButton and Contact's
          // Autocomplete both resist being compressed below their content
          // height) define the row height, and every other field stretches
          // to match — rather than forcing an arbitrary fixed height that
          // some fields can't actually be compressed to.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 140,
                  child: _stretch(_buildDateFieldCompact()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildContactField(
                    decoration: dec.copyWith(labelText: 'Contact'),
                    stretch: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stretch(GlAccountDropdown(
                    allEntries: widget.glEntries,
                    value: _selectedGl,
                    decoration: dec.copyWith(labelText: 'GL Account'),
                    directionFilter:
                        isMoneyOut ? GlDirection.moneyOut : GlDirection.moneyIn,
                    compact: true,
                    onChanged: widget.isSaving ? null : _onGlChangedCompact,
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: Account | Receipt | Description | Total | Amt ex GST | GST
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stretch(_buildAccountDropdown(width: 140, compact: true)),
                const SizedBox(width: 8),
                if (isMoneyOut) ...[
                  SizedBox(
                    width: 160,
                    child: _stretch(_isCash
                        ? TextFormField(
                            controller: _cashReceiptController,
                            enabled: !widget.isSaving,
                            expands: true,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: dec.copyWith(labelText: 'Receipt No.'),
                          )
                        : TextFormField(
                            controller: _receiptOutController,
                            enabled: !widget.isSaving,
                            expands: true,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: dec.copyWith(labelText: 'Receipt No.'),
                          )),
                  ),
                  const SizedBox(width: 8),
                ] else if (_isCash) ...[
                  SizedBox(
                    width: 160,
                    child: _stretch(TextFormField(
                      controller: _cashReceiptController,
                      enabled: !widget.isSaving,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: dec.copyWith(labelText: 'Receipt No.'),
                    )),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _stretch(TextFormField(
                    controller: _descriptionController,
                    enabled: !widget.isSaving,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: dec.copyWith(labelText: 'Description'),
                  )),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: _stretch(TextFormField(
                    controller: _totalController,
                    enabled: !widget.isSaving,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 13),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    ],
                    onChanged: _handleTotalChanged,
                    decoration:
                        dec.copyWith(labelText: 'Total', prefixText: '\$ '),
                  )),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: _stretch(TextFormField(
                    controller: _amountController,
                    enabled: !widget.isSaving,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 13),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    ],
                    onChanged: _handleAmountChanged,
                    decoration: dec.copyWith(
                        labelText: 'Amt ex GST', prefixText: '\$ '),
                  )),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: _stretch(TextFormField(
                    controller: _gstController,
                    enabled: !widget.isSaving && _gstApplicable,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.center,
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
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Save / Cancel
          Row(
            children: [
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
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
    // A bare Text-in-InputDecorator doesn't reliably grow to fill a tight
    // stretched-row height the way a TextFormField does (see _stretch above)
    // — using a read-only TextFormField here instead gives Date the same
    // sizing behaviour as every other compact field. `key: ValueKey(_date)`
    // forces a fresh element (and thus a fresh `initialValue`) whenever the
    // date picker or reset() changes `_date`, since TextFormField otherwise
    // only reads `initialValue` once, at construction.
    return TextFormField(
      key: ValueKey(_date),
      readOnly: true,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.center,
      initialValue:
          '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
      style: const TextStyle(fontSize: 13),
      enabled: !widget.isSaving,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) setState(() => _date = picked);
      },
      decoration: dec.copyWith(labelText: 'Date'),
    );
  }
}
