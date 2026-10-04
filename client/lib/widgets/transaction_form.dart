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
import 'package:provider/provider.dart';

import '../models/bank_account_summary.dart';
import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/reference_data_cache.dart';
import 'gl_account_dropdown.dart';

enum _AmountAnchor { total, amount }

/// One general ledger line of a transaction form — the part of the payment
/// coded to a single general ledger account.
class TransactionFormLine {
  final GeneralLedgerEntry gl;
  final int amountCents;
  final int gstCents;
  final String description;

  const TransactionFormLine({
    required this.gl,
    required this.amountCents,
    required this.gstCents,
    required this.description,
  });

  /// JSON shape of one entry in the API's `lines` array.
  Map<String, dynamic> toJson() => {
        'generalLedgerId': gl.id,
        'amount': amountCents,
        'gstAmount': gstCents,
        'description': description,
      };
}

/// The text controllers and selection backing one general ledger line of the
/// form: the always-present first line, or an additional split line.
class _LineFields {
  GeneralLedgerEntry? gl;
  final TextEditingController amount = TextEditingController();
  final TextEditingController gst = TextEditingController();
  final TextEditingController total = TextEditingController();
  final TextEditingController description = TextEditingController();

  /// Which of Total / Amount-ex-GST the user last edited directly.
  /// When GST is then edited, the *other* one is recalculated so the field
  /// the user just set is preserved.
  _AmountAnchor anchor = _AmountAnchor.total;

  void dispose() {
    amount.dispose();
    gst.dispose();
    total.dispose();
    description.dispose();
  }
}

/// Validated form data passed to the parent's save handler.
class TransactionFormData {
  final DateTime date;
  final String? existingContactId;
  final String? newContactName;
  final GeneralLedgerEntry gl;
  final int amountCents;
  final int gstCents;
  final String receiptNumber;
  final String? paymentReference;
  final String description;
  final bool isCash;
  final String? bankAccountId;

  /// Additional general ledger lines when a Money-Out payment is split
  /// across several GL codes. Empty for an ordinary transaction, where
  /// [gl] / [amountCents] / [gstCents] / [description] are the whole of it;
  /// when non-empty those fields describe the first line only.
  final List<TransactionFormLine> extraLines;

  const TransactionFormData({
    required this.date,
    this.existingContactId,
    this.newContactName,
    required this.gl,
    required this.amountCents,
    required this.gstCents,
    required this.receiptNumber,
    this.paymentReference,
    required this.description,
    this.isCash = false,
    this.bankAccountId,
    this.extraLines = const [],
  });

  /// Whether the payment is coded to more than one general ledger account.
  bool get isSplit => extraLines.isNotEmpty;

  /// Every general ledger line of the transaction, first line first.
  List<TransactionFormLine> get lines => [
        TransactionFormLine(
          gl: gl,
          amountCents: amountCents,
          gstCents: gstCents,
          description: description,
        ),
        ...extraLines,
      ];
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

  /// When [initial] is the first line of a split transaction, the remaining
  /// lines of that split in line order. Empty for an ordinary transaction.
  final List<TransactionEntry> initialSplitLines;
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
    this.initialSplitLines = const [],
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

  GlDirection? _selectedDirection;

  /// The first general ledger line — the whole transaction unless it's split.
  final _LineFields _primary = _LineFields();

  /// Additional general ledger lines of a split Money-Out payment. Empty for
  /// an ordinary transaction.
  final List<_LineFields> _extraLines = [];

  /// The whole payment's total (inc GST) in cents while it is split. The
  /// first line then holds whatever is left of it once the additional lines
  /// are taken out, so adding to a split line reduces the first line rather
  /// than growing the payment. Null when the transaction isn't split, or the
  /// first line's total hasn't been entered yet.
  int? _paymentTotalCents;

  /// Mirrors the server's cap on the number of lines in one split.
  static const int _maxLines = 50;

  GeneralLedgerEntry? get _selectedGl => _primary.gl;
  set _selectedGl(GeneralLedgerEntry? gl) => _primary.gl = gl;
  TextEditingController get _amountController => _primary.amount;
  TextEditingController get _gstController => _primary.gst;
  TextEditingController get _totalController => _primary.total;
  TextEditingController get _descriptionController => _primary.description;
  set _anchor(_AmountAnchor anchor) => _primary.anchor = anchor;

  List<_LineFields> get _allLines => [_primary, ..._extraLines];

  /// The account (or the entity's system Cash account) this transaction
  /// relates to. Null means "not yet chosen" — only auto-defaulted when
  /// there is exactly one non-cash account, otherwise the user must pick.
  String? _selectedBankAccountId;
  final TextEditingController _cashReceiptController = TextEditingController();
  final TextEditingController _receiptOutController = TextEditingController();
  final TextEditingController _paymentReferenceController = TextEditingController();

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
      _paymentReferenceController.text = t.paymentReference ?? '';
      if (_selectedGl?.direction == GlDirection.moneyOut) {
        if (t.isCash) {
          _cashReceiptController.text = t.receiptNumber;
        } else {
          _receiptOutController.text = t.receiptNumber;
        }
      } else if (t.isCash) {
        _cashReceiptController.text = t.receiptNumber;
      }
      for (final TransactionEntry extra in widget.initialSplitLines) {
        final _LineFields line = _LineFields()
          ..gl = widget.glEntries
              .where((g) => g.id == extra.generalLedgerId)
              .firstOrNull;
        line.amount.text = _centsToString(extra.amount);
        line.gst.text = _centsToString(extra.gstAmount);
        line.total.text = _centsToString(extra.totalAmount);
        line.description.text = extra.description;
        _extraLines.add(line);
      }
      if (_extraLines.isNotEmpty) {
        _paymentTotalCents = t.totalAmount + _extraLinesTotalCents;
      }
    } else {
      _date = DateTime.now();
      _receiptOutController.text = widget.nextMoneyOutReceipt;
      _selectedBankAccountId = _singleNonCashAccountId;
    }
    _loadGstRate();
  }

  @override
  void dispose() {
    for (final _LineFields line in _allLines) {
      line.dispose();
    }
    _cashReceiptController.dispose();
    _receiptOutController.dispose();
    _paymentReferenceController.dispose();
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

  /// GST is driven by the GL account's `gstApplicable` flag, except on
  /// Money-Out: a contact that isn't GST-registered can't legally charge
  /// GST, so GST is forced to zero regardless of the GL account until a
  /// GST-registered contact is selected. Money-In is unaffected.
  ///
  /// This only governs the *default* auto-calculated value — the GST field
  /// itself stays editable regardless, so an unusual case can be entered
  /// manually by overriding it (see [_buildAmountsRow] / compact GST field).
  bool get _gstApplicable => _gstApplicableFor(_selectedGl);

  /// [_gstApplicable] for an arbitrary line's GL account — each line of a
  /// split follows its own account's `gstApplicable` flag.
  bool _gstApplicableFor(GeneralLedgerEntry? gl) {
    if (!(gl?.gstApplicable ?? false)) return false;
    if (!_isMoneyOut) return true;
    return _selectedContact?.gstRegistered ?? false;
  }

  /// The GST rate effective on the transaction's date, fetched from the
  /// server (`GET /gst-rates/effective`, mirroring
  /// `GetEffectiveGstRateUseCase`) rather than a hardcoded 10% — so a rate
  /// change on a known future/past date is picked up correctly. Loaded via
  /// [_loadGstRate] (initially, and whenever [_date] changes) rather than
  /// read synchronously, since fetching it is a network call; defaults to
  /// 10% until that resolves or if the entity has no rate configured.
  ///
  /// [ReferenceDataCache.effectiveGstRate]'s cached-list lookup isn't used
  /// here because its backing list (`GET /gst-rates`) is administrator-only,
  /// while every role needs this to price a transaction.
  double _gstRate = 0.10;

  /// Loads [_gstRate] for the current [_date] only — deliberately does not
  /// recalculate the amount fields. Called from [initState], where an
  /// edited transaction's fields are pre-filled from its saved (possibly
  /// manually-overridden) amounts; recalculating here would silently
  /// discard that override the moment the form opens. Callers that change
  /// something the displayed amounts should react to (the date) recalculate
  /// explicitly afterwards — see [_onDateChanged].
  Future<void> _loadGstRate() async {
    final cache = context.read<ReferenceDataCache>();
    final rate = await cache.fetchEffectiveGstRate(_date);
    if (!mounted) return;
    setState(() => _gstRate = rate?.rate ?? 0.10);
  }

  /// Sets [_date], reloads [_gstRate] for it, then recalculates the amount
  /// fields — the rate may differ on the new date, so (unlike the initial
  /// load) the displayed amounts must be refreshed to match.
  Future<void> _onDateChanged(DateTime picked) async {
    setState(() => _date = picked);
    await _loadGstRate();
    if (!mounted) return;
    setState(_recalculateGstFields);
  }

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
      _paymentReferenceController.clear();
      _anchor = _AmountAnchor.total;
      _clearExtraLines();
    });
    // Full-layout forms are long-lived (the parent calls reset() after each
    // save rather than remounting the widget via GlobalKey), so initState's
    // one-time load isn't enough — re-fetch for the new date, otherwise
    // every entry after a rate change keeps using whatever was effective
    // when the form first mounted.
    _loadGstRate();
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
      paymentReference: _isMoneyOut && _paymentReferenceController.text.trim().isNotEmpty
          ? _paymentReferenceController.text.trim()
          : null,
      description: _descriptionController.text.trim(),
      isCash: _isCash,
      bankAccountId: _selectedBankAccountId,
      extraLines: [
        for (final _LineFields line in _extraLines)
          TransactionFormLine(
            gl: line.gl!,
            amountCents: _dollarsToCents(_parseAmount(line.amount.text)!),
            gstCents: _dollarsToCents(_parseAmount(line.gst.text)!),
            description: line.description.text.trim(),
          ),
      ],
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
    if (_extraLines.isNotEmpty && amount != null && amount <= 0) {
      return 'The split lines use up the whole payment or more — '
          'nothing is left on the first line';
    }
    if (amount == null || amount <= 0)
      return 'Amount must be greater than zero';
    final gst = _parseAmount(_gstController.text);
    if (gst == null || gst < 0) return 'GST amount must be zero or more';
    for (int i = 0; i < _extraLines.length; i++) {
      final _LineFields line = _extraLines[i];
      final String label = 'Split line ${i + 2}';
      if (line.gl == null) {
        return '$label: please select a general ledger account';
      }
      final lineAmount = _parseAmount(line.amount.text);
      if (lineAmount == null || lineAmount <= 0) {
        return '$label: amount must be greater than zero';
      }
      final lineGst = _parseAmount(line.gst.text);
      if (lineGst == null || lineGst < 0) {
        return '$label: GST amount must be zero or more';
      }
    }
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
    _lineAmountChanged(_primary, value);
    _onPrimaryAmountsEdited();
  }

  void _handleTotalChanged(String value) {
    _lineTotalChanged(_primary, value);
    _onPrimaryAmountsEdited();
  }

  void _handleGstChanged(String value) {
    _lineGstChanged(_primary, value);
    _onPrimaryAmountsEdited();
  }

  void _extraAmountChanged(_LineFields line, String value) {
    _lineAmountChanged(line, value);
    _rebalancePrimary();
  }

  void _extraTotalChanged(_LineFields line, String value) {
    _lineTotalChanged(line, value);
    _rebalancePrimary();
  }

  void _extraGstChanged(_LineFields line, String value) {
    _lineGstChanged(line, value);
    _rebalancePrimary();
  }

  void _lineAmountChanged(_LineFields line, String value) {
    line.anchor = _AmountAnchor.amount;
    final bool gstApplicable = _gstApplicableFor(line.gl);
    final amount = _parseAmount(value);
    if (amount == null) {
      line.gst.text = gstApplicable ? '' : '0.00';
      line.total.clear();
      return;
    }
    final amountCents = _dollarsToCents(amount);
    if (gstApplicable) {
      final gstCents = (amountCents * _gstRate).round();
      line.gst.text = _centsToString(gstCents);
      line.total.text = _centsToString(amountCents + gstCents);
    } else {
      line.gst.text = '0.00';
      line.total.text = value;
    }
  }

  void _lineTotalChanged(_LineFields line, String value) {
    line.anchor = _AmountAnchor.total;
    final bool gstApplicable = _gstApplicableFor(line.gl);
    final total = _parseAmount(value);
    if (total == null) {
      line.amount.clear();
      line.gst.text = gstApplicable ? '' : '0.00';
      return;
    }
    final totalCents = _dollarsToCents(total);
    if (gstApplicable) {
      final rate = _gstRate;
      final gstCents = (totalCents * rate / (1 + rate)).round();
      line.amount.text = _centsToString(totalCents - gstCents);
      line.gst.text = _centsToString(gstCents);
    } else {
      line.amount.text = value;
      line.gst.text = '0.00';
    }
  }

  /// Recalculates whichever of Total / Amount-ex-GST was *not* last edited
  /// directly by the user, so the field they just set is preserved.
  void _lineGstChanged(_LineFields line, String value) {
    final gst = _parseAmount(value);
    if (gst == null) return;
    final gstCents = _dollarsToCents(gst);
    if (line.anchor == _AmountAnchor.total) {
      final total = _parseAmount(line.total.text);
      if (total == null) return;
      line.amount.text = _centsToString(_dollarsToCents(total) - gstCents);
    } else {
      final amount = _parseAmount(line.amount.text);
      if (amount == null) return;
      line.total.text = _centsToString(_dollarsToCents(amount) + gstCents);
    }
  }

  /// Recomputes the GST/Amount/Total trio of every line after something that
  /// can flip GST applicability changes for all of them at once — the
  /// (Money-Out only) selected contact's GST-registration status, or the
  /// date's effective rate.
  void _recalculateGstFields() {
    _allLines.forEach(_recalculateLine);
    _rebalancePrimary();
  }

  /// Recomputes one line's GST/Amount/Total trio after its GST applicability
  /// may have changed (e.g. its GL account). Mirrors whichever of
  /// [_lineAmountChanged] / [_lineTotalChanged] matches the field the user
  /// last edited, so that field's value is preserved.
  void _recalculateLine(_LineFields line) {
    if (_gstApplicableFor(line.gl)) {
      final rate = _gstRate;
      if (line.anchor == _AmountAnchor.total) {
        final total = _parseAmount(line.total.text);
        if (total == null) return;
        final totalCents = _dollarsToCents(total);
        final gstCents = (totalCents * rate / (1 + rate)).round();
        line.amount.text = _centsToString(totalCents - gstCents);
        line.gst.text = _centsToString(gstCents);
      } else {
        final amount = _parseAmount(line.amount.text);
        if (amount == null) return;
        final amountCents = _dollarsToCents(amount);
        final gstCents = (amountCents * rate).round();
        line.gst.text = _centsToString(gstCents);
        line.total.text = _centsToString(amountCents + gstCents);
      }
    } else {
      line.gst.text = '0.00';
      if (line.anchor == _AmountAnchor.total) {
        final total = _parseAmount(line.total.text);
        if (total != null) line.amount.text = line.total.text;
      } else {
        final amount = _parseAmount(line.amount.text);
        if (amount != null) line.total.text = line.amount.text;
      }
    }
  }

  // ── Split lines ────────────────────────────────────────────────────────────

  /// Total (inc GST) of the additional lines, in cents, ignoring lines whose
  /// amounts aren't filled in yet.
  int get _extraLinesTotalCents {
    int cents = 0;
    for (final _LineFields line in _extraLines) {
      final total = _parseAmount(line.total.text);
      if (total != null) cents += _dollarsToCents(total);
    }
    return cents;
  }

  /// Sets the first line to what is left of the payment once the additional
  /// lines are taken out, keeping the payment total fixed. No-op when the
  /// transaction isn't split or the payment total isn't known yet.
  void _rebalancePrimary() {
    final int? paymentTotal = _paymentTotalCents;
    if (paymentTotal == null || _extraLines.isEmpty) return;
    _primary.total.text = _centsToString(paymentTotal - _extraLinesTotalCents);
    _primary.anchor = _AmountAnchor.total;
    _recalculateLine(_primary);
  }

  /// The user typed into the first line's own amounts while the payment is
  /// split: that redefines the payment total as the first line plus the
  /// additional lines.
  void _onPrimaryAmountsEdited() {
    if (_extraLines.isEmpty) return;
    final total = _parseAmount(_primary.total.text);
    _paymentTotalCents =
        total == null ? null : _dollarsToCents(total) + _extraLinesTotalCents;
  }

  void _addSplitLine() => setState(() {
        if (_extraLines.isEmpty) {
          // The first line carries the whole payment until lines are split
          // off it.
          final total = _parseAmount(_primary.total.text);
          _paymentTotalCents = total == null ? null : _dollarsToCents(total);
        }
        _extraLines.add(_LineFields());
      });

  void _removeSplitLine(_LineFields line) {
    setState(() {
      _extraLines.remove(line);
      // The removed line's amount goes back onto the first line.
      if (_extraLines.isEmpty) {
        final int? paymentTotal = _paymentTotalCents;
        if (paymentTotal != null) {
          _primary.total.text = _centsToString(paymentTotal);
          _primary.anchor = _AmountAnchor.total;
          _recalculateLine(_primary);
        }
        _paymentTotalCents = null;
      } else {
        _rebalancePrimary();
      }
    });
    // Dispose after the frame that drops the row's fields, not before —
    // they still hold the controllers until then.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  /// Drops every additional line — a split only applies to Money-Out, so it
  /// can't survive the form being reset or switched to Money-In. Must be
  /// called inside [setState].
  void _clearExtraLines() {
    final List<_LineFields> removed = List.of(_extraLines);
    _extraLines.clear();
    _paymentTotalCents = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final _LineFields line in removed) {
        line.dispose();
      }
    });
  }

  /// Sum of every line's Total (inc GST) and GST, in cents, ignoring lines
  /// whose amounts aren't filled in yet.
  ({int totalCents, int gstCents}) get _paymentTotals {
    int totalCents = 0;
    int gstCents = 0;
    for (final _LineFields line in _allLines) {
      final total = _parseAmount(line.total.text);
      final gst = _parseAmount(line.gst.text);
      if (total != null) totalCents += _dollarsToCents(total);
      if (gst != null) gstCents += _dollarsToCents(gst);
    }
    return (totalCents: totalCents, gstCents: gstCents);
  }

  void _onGlChangedFull(GeneralLedgerEntry? gl) {
    setState(() {
      _selectedGl = gl;
      _selectedDirection = gl?.direction;
      _amountController.clear();
      _gstController.text = _gstApplicable ? '' : '0.00';
      _totalController.clear();
      _receiptOutController.text = gl?.direction == GlDirection.moneyOut
          ? widget.nextMoneyOutReceipt
          : '';
      _anchor = _AmountAnchor.total;
      _paymentTotalCents = null;
      if (gl?.direction != GlDirection.moneyOut) _clearExtraLines();
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
        _paymentReferenceController.clear();
        _anchor = _AmountAnchor.total;
        _clearExtraLines();
      }
    });
  }

  void _onGlChangedCompact(GeneralLedgerEntry? gl) {
    setState(() {
      _selectedGl = gl;
      if (gl != null && !_gstApplicable) {
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
        if (_isMoneyOut) _buildSplitSection(),
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
              if (picked != null) _onDateChanged(picked);
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
        _recalculateGstFields();
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
                _recalculateGstFields();
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
            decoration: decoration.copyWith(
                labelText:
                    _extraLines.isEmpty ? 'Total Amount' : 'Remaining Amount'),
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
            enabled: !widget.isSaving && _selectedGl != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            onChanged: _handleGstChanged,
            decoration: decoration.copyWith(
              labelText: 'GST',
              helperText: _gstApplicable ? null : 'Not normally applicable — override if needed',
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(width: 16),
            SizedBox(width: 220, child: _buildPaymentReferenceField()),
          ],
        ),
      ],
    );
  }

  /// Optional Money-Out reference used in place of the Receipt Number as the
  /// lodgement reference when generating the bank (ABA) upload file.
  Widget _buildPaymentReferenceField() {
    return TextFormField(
      controller: _paymentReferenceController,
      enabled: !widget.isSaving,
      decoration: const InputDecoration(
        labelText: 'Payment Reference (optional)',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperText: 'Used instead of Receipt No. on bank upload',
      ),
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

  // ── Split across GL codes (Money-Out) ──────────────────────────────────────

  /// The additional general ledger lines of a split payment, the button that
  /// adds one, and — once there is more than one line — the payment total.
  /// The first line is the form's ordinary GL / Description / amount fields.
  Widget _buildSplitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final _LineFields line in _extraLines) _buildSplitLineRow(line),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: widget.isSaving || _allLines.length >= _maxLines
                    ? null
                    : _addSplitLine,
                icon: const Icon(Icons.call_split, size: 16),
                label: Text(
                  _extraLines.isEmpty ? 'Split across GL codes' : 'Add GL line',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const Spacer(),
              if (_extraLines.isNotEmpty) _buildPaymentTotal(),
            ],
          ),
        ),
      ],
    );
  }

  /// Running total across every line — what will actually be paid to the
  /// contact. Listens to the amount fields directly so it updates as the
  /// user types without the handlers needing to call [setState].
  Widget _buildPaymentTotal() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        for (final _LineFields line in _allLines) ...[line.total, line.gst],
      ]),
      builder: (context, _) {
        final totals = _paymentTotals;
        return Text(
          'Payment total \$${_centsToString(totals.totalCents)}'
          '  (incl. GST \$${_centsToString(totals.gstCents)})',
          key: const ValueKey('split-payment-total'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        );
      },
    );
  }

  /// One additional general ledger line: Remove | GL Account | Description |
  /// Total | Amt ex GST | GST. The amount columns use the same widths as the
  /// compact layout's first-line fields so they line up beneath them.
  Widget _buildSplitLineRow(_LineFields line) {
    const dec = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
    final bool gstApplicable = _gstApplicableFor(line.gl);

    Widget amountField({
      required TextEditingController controller,
      required String label,
      required void Function(_LineFields, String) onChanged,
      required double width,
      bool greyed = false,
    }) =>
        SizedBox(
          width: width,
          child: _stretch(TextFormField(
            controller: controller,
            enabled: !widget.isSaving,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 13),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            onChanged: (value) => onChanged(line, value),
            decoration: dec.copyWith(
              labelText: label,
              prefixText: '\$ ',
              fillColor: greyed ? Colors.grey.shade100 : null,
              filled: greyed,
            ),
          )),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconButton(
              tooltip: 'Remove this GL line',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed:
                  widget.isSaving ? null : () => _removeSplitLine(line),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _stretch(GlAccountDropdown(
                allEntries: widget.glEntries,
                value: line.gl,
                decoration: dec.copyWith(labelText: 'GL Account'),
                directionFilter: GlDirection.moneyOut,
                compact: true,
                onChanged: widget.isSaving
                    ? null
                    : (gl) => setState(() {
                          line.gl = gl;
                          _recalculateLine(line);
                          _rebalancePrimary();
                        }),
              )),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _stretch(TextFormField(
                controller: line.description,
                enabled: !widget.isSaving,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 13),
                decoration: dec.copyWith(labelText: 'Description'),
              )),
            ),
            const SizedBox(width: 8),
            amountField(
              controller: line.total,
              label: 'Total',
              onChanged: _extraTotalChanged,
              width: 110,
            ),
            const SizedBox(width: 8),
            amountField(
              controller: line.amount,
              label: 'Amt ex GST',
              onChanged: _extraAmountChanged,
              width: 110,
            ),
            const SizedBox(width: 8),
            amountField(
              controller: line.gst,
              label: 'GST',
              onChanged: _extraGstChanged,
              width: 90,
              greyed: !gstApplicable,
            ),
          ],
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
                    width: 100,
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
                  SizedBox(
                    width: 100,
                    child: _stretch(TextFormField(
                      controller: _paymentReferenceController,
                      enabled: !widget.isSaving,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: dec.copyWith(labelText: 'Payment Ref.'),
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
                    // While split, the first line shows what is left of the
                    // payment after the additional lines.
                    decoration: dec.copyWith(
                        labelText: _extraLines.isEmpty ? 'Total' : 'Remaining',
                        prefixText: '\$ '),
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
          if (isMoneyOut) _buildSplitSection(),
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
        if (picked != null) _onDateChanged(picked);
      },
      decoration: dec.copyWith(labelText: 'Date'),
    );
  }
}
