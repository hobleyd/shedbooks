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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/bank_account_summary.dart';
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/invoice_entry.dart';
import '../models/invoice_line_item.dart';
import '../services/api_client.dart';
import '../services/reference_data_cache.dart';
import '../widgets/contact_picker.dart';
import '../widgets/gl_account_dropdown.dart';
import '../widgets/invoice_pdf.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  // Reference data
  List<BankAccountSummary> _bankAccounts = [];

  // GL accounts, GST rate, entity details and contacts are shared via the
  // cache.
  List<GeneralLedgerEntry> get _glAccounts => context.read<ReferenceDataCache>().glEntries;
  double get _gstRate => context.read<ReferenceDataCache>().effectiveGstRate()?.rate ?? 0.10;
  EntityDetails? get _entityDetails => context.read<ReferenceDataCache>().entityDetails;
  Map<String, ContactEntry> get _contacts =>
      {for (final c in context.read<ReferenceDataCache>().contacts) c.id: c};

  // Invoice list
  List<InvoiceEntry> _invoices = [];
  String _nextInvoiceNumber = '';

  bool _loading = true;

  // Inline form state
  bool _addingNew = false;
  String? _editingId;
  String? _editingContactName;
  bool _editingContactGstRegistered = false;
  bool _inlineSaving = false;
  bool _inlineLoadingDetails = false;

  // Inline form controllers (created on open, disposed on close)
  ContactPickerController? _inlineContactController;
  TextEditingController? _inlineNumberController;
  DateTime _inlineDate = DateTime.now();
  BankAccountSummary? _inlineBankAccount;
  List<InvoiceLineItem> _inlineLineItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _disposeInlineControllers();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final client = context.read<ApiClient>();
      final cache = context.read<ReferenceDataCache>();
      final results = await Future.wait([
        client.get('/invoices/next-number'),
        client.get('/invoices'),
        client.get('/bank-reconciliation/bank-accounts'),
      ]);
      await Future.wait([
        cache.refreshGl(),
        cache.refreshGstRates(),
        cache.refreshEntityDetails(),
        cache.refreshContacts(),
      ]);

      if (!mounted) return;

      if (results[0].statusCode == 200) {
        _nextInvoiceNumber =
            (jsonDecode(results[0].body) as Map<String, dynamic>)['invoiceNumber'] as String;
      }
      if (results[1].statusCode == 200) {
        final List<dynamic> data = jsonDecode(results[1].body);
        _invoices = data
            .map((e) => InvoiceEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (results[2].statusCode == 200) {
        final List<dynamic> data = jsonDecode(results[2].body);
        _bankAccounts = data
            .map((e) => BankAccountSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackbar('Failed to load data: $e');
      }
    }
  }

  Future<void> _refreshInvoices() async {
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/invoices'),
        client.get('/invoices/next-number'),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        final List<dynamic> data = jsonDecode(results[0].body);
        setState(() {
          _invoices = data
              .map((e) => InvoiceEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
      if (results[1].statusCode == 200) {
        setState(() {
          _nextInvoiceNumber =
              (jsonDecode(results[1].body) as Map<String, dynamic>)['invoiceNumber'] as String;
        });
      }
    } catch (_) {}
  }

  // ── Inline form lifecycle ──────────────────────────────────────────────────

  void _startAdd() {
    _disposeInlineControllers();
    final controller = ContactPickerController(onlyCompanies: true);
    controller.addListener(_updateInlineCalculations);
    setState(() {
      _addingNew = true;
      _editingId = null;
      _inlineContactController = controller;
      _inlineNumberController = TextEditingController(text: _nextInvoiceNumber);
      _inlineDate = DateTime.now();
      _inlineBankAccount =
          _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
      _inlineLineItems = [InvoiceLineItem()];
      _inlineSaving = false;
    });
  }

  Future<void> _startEdit(InvoiceEntry inv) async {
    _disposeInlineControllers();
    setState(() {
      _editingId = inv.id;
      _editingContactName =
          _contacts[inv.contactId]?.name ?? inv.contactId;
      _editingContactGstRegistered =
          _contacts[inv.contactId]?.gstRegistered ?? false;
      _addingNew = false;
      _inlineLoadingDetails = true;
      _inlineSaving = false;
    });

    try {
      final client = context.read<ApiClient>();
      final res = await client.get('/invoices/${inv.id}');
      if (!mounted || res.statusCode != 200) {
        _cancelInline();
        return;
      }
      final detail = InvoiceEntry.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);

      final items = (detail.lineItems ?? []).map((entry) {
        final item = InvoiceLineItem();
        item.descriptionController.text = entry.description;
        final matches = _glAccounts.where((g) => g.id == entry.generalLedgerId);
        item.glAccount = matches.isNotEmpty ? matches.first : null;
        item.amountCents = entry.amountCents;
        item.gstCents = entry.gstCents;
        item.amountController.text =
            (entry.amountCents / 100).toStringAsFixed(2);
        return item;
      }).toList();
      if (items.isEmpty) items.add(InvoiceLineItem());

      final bankAccount = inv.bankAccountId != null
          ? _bankAccounts
              .where((a) => a.id == inv.bankAccountId)
              .firstOrNull
          : null;

      setState(() {
        _inlineNumberController =
            TextEditingController(text: inv.invoiceNumber);
        _inlineDate = DateTime.parse(inv.invoiceDate);
        _inlineBankAccount =
            bankAccount ?? (_bankAccounts.isNotEmpty ? _bankAccounts.first : null);
        _inlineLineItems = items;
        _inlineLoadingDetails = false;
      });
    } catch (e) {
      if (mounted) {
        _cancelInline();
        _showSnackbar('Failed to load invoice: $e');
      }
    }
  }

  void _cancelInline() {
    _disposeInlineControllers();
    setState(() {
      _addingNew = false;
      _editingId = null;
      _editingContactName = null;
      _inlineLoadingDetails = false;
      _inlineSaving = false;
    });
  }

  void _disposeInlineControllers() {
    _inlineContactController?.removeListener(_updateInlineCalculations);
    _inlineContactController?.dispose();
    _inlineContactController = null;
    _inlineNumberController?.dispose();
    _inlineNumberController = null;
    for (final item in _inlineLineItems) {
      item.dispose();
    }
    _inlineLineItems = [];
  }

  // ── Inline form helpers ────────────────────────────────────────────────────

  void _addInlineLineItem() {
    setState(() => _inlineLineItems.add(InvoiceLineItem()));
  }

  void _removeInlineLineItem(int index) {
    if (_inlineLineItems.length > 1) {
      setState(() {
        _inlineLineItems[index].dispose();
        _inlineLineItems.removeAt(index);
      });
    }
  }

  void _updateInlineCalculations() {
    final gstRegistered = _addingNew
        ? (_inlineContactController?.gstRegistered ?? false)
        : _editingContactGstRegistered;
    for (final item in _inlineLineItems) {
      item.updateAmounts(_gstRate, contactGstRegistered: gstRegistered);
    }
    setState(() {});
  }

  int get _inlineTotalCents =>
      _inlineLineItems.fold(0, (s, i) => s + i.amountCents + i.gstCents);

  int get _inlineTotalGstCents =>
      _inlineLineItems.fold(0, (s, i) => s + i.gstCents);

  // ── Save / delete ──────────────────────────────────────────────────────────

  Future<void> _saveInline() async {
    final isEdit = _editingId != null;
    final numberText = _inlineNumberController?.text.trim() ?? '';

    if (!isEdit) {
      final controller = _inlineContactController!;
      if (controller.selectedContact == null && !controller.isNew) {
        _showSnackbar('Please select or create a contact.');
        return;
      }
      if (controller.isNew && controller.nameController.text.trim().isEmpty) {
        _showSnackbar('Please enter a name for the new contact.');
        return;
      }
    }
    if (numberText.isEmpty) {
      _showSnackbar('Please enter an invoice number.');
      return;
    }
    for (final item in _inlineLineItems) {
      if (item.glAccount == null) {
        _showSnackbar('All line items must have a GL account.');
        return;
      }
      if (item.amountCents <= 0) {
        _showSnackbar('All line items must have an amount greater than zero.');
        return;
      }
    }

    setState(() => _inlineSaving = true);

    try {
      final client = context.read<ApiClient>();

      if (isEdit) {
        final body = jsonEncode({
          'invoiceNumber': numberText,
          'invoiceDate': DateFormat('yyyy-MM-dd').format(_inlineDate),
          'bankAccountId': _inlineBankAccount?.id,
          'lineItems': _inlineLineItems
              .map((item) => {
                    'description': item.descriptionController.text.trim(),
                    'generalLedgerId': item.glAccount!.id,
                    'amountCents': item.amountCents,
                    'gstCents': item.gstCents,
                  })
              .toList(),
        });
        final res = await client.put('/invoices/$_editingId', body);
        if (!mounted) return;
        if (res.statusCode != 200) {
          final err =
              (jsonDecode(res.body) as Map?)?['error']?.toString() ??
                  'Update failed (${res.statusCode})';
          throw Exception(err);
        }
      } else {
        final controller = _inlineContactController!;
        String contactId;
        if (controller.isNew) {
          final contactBody = jsonEncode({
            'name': controller.nameController.text.trim(),
            'contactType': ContactType.company.name,
            'gstRegistered': controller.gstRegistered,
            'abn': controller.abnController.text.trim(),
          });
          final res = await client.post('/contacts', contactBody);
          if (!mounted) return;
          if (res.statusCode != 201) throw Exception('Failed to create contact');
          contactId = (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
          context.read<ReferenceDataCache>().refreshContacts();
        } else {
          contactId = controller.selectedContact!.id;
        }

        final body = jsonEncode({
          'invoiceNumber': numberText,
          'invoiceDate': DateFormat('yyyy-MM-dd').format(_inlineDate),
          'contactId': contactId,
          'bankAccountId': _inlineBankAccount?.id,
          'lineItems': _inlineLineItems
              .map((item) => {
                    'description': item.descriptionController.text.trim(),
                    'generalLedgerId': item.glAccount!.id,
                    'amountCents': item.amountCents,
                    'gstCents': item.gstCents,
                  })
              .toList(),
        });
        final res = await client.post('/invoices', body);
        if (!mounted) return;
        if (res.statusCode != 201) {
          final err =
              (jsonDecode(res.body) as Map?)?['error']?.toString() ??
                  'Save failed (${res.statusCode})';
          throw Exception(err);
        }
      }

      _cancelInline();
      await _refreshInvoices();
      if (mounted) {
        _showSnackbar(isEdit ? 'Invoice updated.' : 'Invoice saved.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineSaving = false);
        _showSnackbar(isEdit ? 'Failed to update: $e' : 'Failed to save: $e');
      }
    }
  }

  Future<void> _confirmDelete(InvoiceEntry inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content:
            Text('Delete invoice ${inv.invoiceNumber}? This cannot be undone.'),
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

    try {
      final client = context.read<ApiClient>();
      final res = await client.delete('/invoices/${inv.id}');
      if (!mounted) return;
      if (res.statusCode != 204) {
        final err =
            (jsonDecode(res.body) as Map?)?['error']?.toString() ??
                'Delete failed (${res.statusCode})';
        throw Exception(err);
      }
      await _refreshInvoices();
    } catch (e) {
      if (mounted) _showSnackbar('Failed to delete: $e');
    }
  }

  Future<void> _generatePdfForInvoice(InvoiceEntry inv) async {
    try {
      final client = context.read<ApiClient>();
      final res = await client.get('/invoices/${inv.id}');
      if (!mounted || res.statusCode != 200) {
        _showSnackbar('Failed to load invoice details for PDF.');
        return;
      }
      final detail = InvoiceEntry.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      final contact = _contacts[inv.contactId];
      final bankAccount = inv.bankAccountId != null
          ? _bankAccounts.where((a) => a.id == inv.bankAccountId).firstOrNull
          : null;

      final lineItems = (detail.lineItems ?? []).map((entry) {
        final item = InvoiceLineItem();
        item.descriptionController.text = entry.description;
        item.amountCents = entry.amountCents;
        item.gstCents = entry.gstCents;
        return item;
      }).toList();

      await InvoicePdf.generateAndDownload(
        entity: _entityDetails,
        contactName: contact?.name ?? '',
        contactAbn: contact?.abn ?? '',
        contactGstRegistered: contact?.gstRegistered ?? false,
        invoiceNumber: inv.invoiceNumber,
        invoiceDate: DateTime.parse(inv.invoiceDate),
        lineItems: lineItems,
        formatCents: _formatCents,
        bankAccount: bankAccount,
      );

      for (final item in lineItems) {
        item.dispose();
      }
    } catch (e) {
      if (mounted) _showSnackbar('Failed to generate PDF: $e');
    }
  }

  // ── Formatting ─────────────────────────────────────────────────────────────

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

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<ReferenceDataCache>();
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Invoices',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: _buildTable(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final isAdmin = context.read<AuthState>().isAdmin;
    final canEdit = context.read<AuthState>().canEdit;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text('Invoice #',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 90,
                  child: Text('Date',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Contact',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 110,
                  child: Text('Total',
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 70,
                  child: Text('Status',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 110),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_invoices.isEmpty && !_addingNew)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Text('No invoices yet.',
                  style: TextStyle(color: Colors.black54)),
            ),

          // Invoice rows
          for (final inv in _invoices)
            if (_editingId == inv.id)
              _editingId != null && _inlineLoadingDetails
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildInlineForm(isEdit: true, editInvoice: inv)
            else
              _buildInvoiceRow(inv, isAdmin: isAdmin, canEdit: canEdit),

          // Add section
          if (_addingNew)
            _buildInlineForm(isEdit: false)
          else if (canEdit)
            _buildAddRow(),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(
    InvoiceEntry inv, {
    required bool isAdmin,
    required bool canEdit,
  }) {
    final contact = _contacts[inv.contactId];
    final parts = inv.invoiceDate.split('-');
    final dateLabel = parts.length == 3
        ? '${parts[2]}/${parts[1]}/${parts[0]}'
        : inv.invoiceDate;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: Text(inv.invoiceNumber,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 90,
                child: Text(dateLabel,
                    style: const TextStyle(fontSize: 13)),
              ),
              Expanded(
                child: Text(contact?.name ?? inv.contactId,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  _formatCents(inv.totalWithGstCents),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: inv.isPaid
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text('Paid',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600)),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text('Unpaid',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600)),
                      ),
              ),
              SizedBox(
                width: 110,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      tooltip: 'Download PDF',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _generatePdfForInvoice(inv),
                    ),
                    if (isAdmin && !inv.isPaid) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _startEdit(inv),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.error),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _confirmDelete(inv),
                      ),
                    ] else
                      const SizedBox(width: 64),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildAddRow() {
    return Column(
      children: [
        InkWell(
          onTap: _startAdd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.add,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('Add invoice',
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

  Widget _buildInlineForm({required bool isEdit, InvoiceEntry? editInvoice}) {
    final gstRegistered = isEdit
        ? _editingContactGstRegistered
        : (_inlineContactController?.gstRegistered ?? false);

    return Column(
      children: [
        Container(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerLowest,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact row
              if (isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Contact: ${_editingContactName ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ContactPicker(controller: _inlineContactController!),
                ),

              // Invoice #, date, bank account
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _inlineNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _inlineDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _inlineDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Invoice Date',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        child: Text(
                            DateFormat('yyyy-MM-dd').format(_inlineDate)),
                      ),
                    ),
                  ),
                  if (_bankAccounts.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Pay Into Bank Account',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        child: DropdownButton<BankAccountSummary>(
                          value: _inlineBankAccount,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          hint: const Text('Select account'),
                          items: _bankAccounts
                              .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.accountName,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _inlineBankAccount = val),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Line items header
              Row(
                children: [
                  Text('Line Items',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addInlineLineItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Line'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Line items
              for (int i = 0; i < _inlineLineItems.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildLineItemRow(i, gstRegistered),
                ),

              // Totals
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (gstRegistered)
                        Text(
                          'GST: ${_formatCents(_inlineTotalGstCents)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      Text(
                        'Total: ${_formatCents(_inlineTotalCents)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _inlineSaving ? null : _cancelInline,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _inlineSaving ? null : _saveInline,
                    child: _inlineSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Update Invoice' : 'Save Invoice'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildLineItemRow(int index, bool gstRegistered) {
    final item = _inlineLineItems[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: item.descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GlAccountDropdown(
            allEntries: _glAccounts,
            value: item.glAccount,
            decoration: const InputDecoration(
              labelText: 'GL Account',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            directionFilter: GlDirection.moneyIn,
            onChanged: (val) {
              setState(() {
                item.glAccount = val;
                _updateInlineCalculations();
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: item.amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              prefixText: r'$ ',
            ),
            onChanged: (_) => _updateInlineCalculations(),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          height: 40,
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: Theme.of(context).colorScheme.error,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeInlineLineItem(index),
          ),
        ),
      ],
    );
  }
}
