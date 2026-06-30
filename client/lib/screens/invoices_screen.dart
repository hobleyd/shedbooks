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
import '../models/contact_entry.dart';
import '../models/entity_details.dart';
import '../models/general_ledger_entry.dart';
import '../models/invoice_entry.dart';
import '../models/invoice_line_item.dart';
import '../services/api_client.dart';
import '../widgets/contact_picker.dart';
import '../widgets/gl_account_dropdown.dart';
import '../widgets/invoice_pdf.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final ContactPickerController _contactController =
      ContactPickerController(onlyCompanies: true);
  final List<InvoiceLineItem> _lineItems = [InvoiceLineItem()];
  final TextEditingController _invoiceNumberController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  List<GeneralLedgerEntry> _glAccounts = [];
  double _gstRate = 0.10;
  EntityDetails? _entityDetails;
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;

  // Invoice list.
  List<InvoiceEntry> _invoices = [];
  Map<String, String> _contactNames = {};

  @override
  void initState() {
    super.initState();
    _contactController.addListener(_updateCalculations);
    _loadData();
  }

  @override
  void dispose() {
    _contactController.removeListener(_updateCalculations);
    _contactController.dispose();
    _invoiceNumberController.dispose();
    for (var item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/general-ledger'),
        client.get('/gst-rates/effective'),
        client.get('/invoices/next-number'),
        client.get('/entity-details'),
        client.get('/invoices'),
        client.get('/contacts'),
      ]);

      if (results[0].statusCode == 200) {
        final List<dynamic> glData = jsonDecode(results[0].body);
        _glAccounts = glData
            .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (results[1].statusCode == 200) {
        final gstData = jsonDecode(results[1].body);
        _gstRate = gstData['rate'] as double;
      }

      if (results[2].statusCode == 200) {
        final numData = jsonDecode(results[2].body) as Map<String, dynamic>;
        _invoiceNumberController.text = numData['invoiceNumber'] as String;
      }

      if (results[3].statusCode == 200) {
        _entityDetails = EntityDetails.fromJson(
            jsonDecode(results[3].body) as Map<String, dynamic>);
      }

      if (results[4].statusCode == 200) {
        final List<dynamic> invoiceData = jsonDecode(results[4].body);
        _invoices = invoiceData
            .map((e) => InvoiceEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (results[5].statusCode == 200) {
        final List<dynamic> contactData = jsonDecode(results[5].body);
        _contactNames = {
          for (final c in contactData.cast<Map<String, dynamic>>())
            c['id'] as String: c['name'] as String,
        };
      }

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _refreshInvoiceList() async {
    try {
      final client = context.read<ApiClient>();
      final res = await client.get('/invoices');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _invoices = data
              .map((e) => InvoiceEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  void _addLineItem() {
    setState(() => _lineItems.add(InvoiceLineItem()));
  }

  void _removeLineItem(int index) {
    if (_lineItems.length > 1) {
      setState(() {
        _lineItems[index].dispose();
        _lineItems.removeAt(index);
      });
    }
  }

  void _updateCalculations() {
    final contactGstRegistered = _contactController.gstRegistered;
    for (var item in _lineItems) {
      item.updateAmounts(_gstRate, contactGstRegistered: contactGstRegistered);
    }
    setState(() {});
  }

  int get _totalCents =>
      _lineItems.fold(0, (sum, item) => sum + item.amountCents + item.gstCents);
  int get _totalGstCents =>
      _lineItems.fold(0, (sum, item) => sum + item.gstCents);

  @override
  Widget build(BuildContext context) {
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
              OutlinedButton.icon(
                onPressed: _saved ? _generatePdf : null,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Generate PDF'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving ? null : _saveInvoice,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Invoice'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  _buildLineItemsSection(),
                  const SizedBox(height: 32),
                  _buildTotalsSection(),
                  const SizedBox(height: 48),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildInvoiceList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ContactPicker(controller: _contactController),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _invoiceNumberController,
                decoration: const InputDecoration(
                  labelText: 'Invoice Number',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _invoiceDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _invoiceDate = picked);
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
                  child: Text(DateFormat('yyyy-MM-dd').format(_invoiceDate)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Line Items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addLineItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Line'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _lineItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildLineItemRow(index),
        ),
      ],
    );
  }

  Widget _buildLineItemRow(int index) {
    final item = _lineItems[index];
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
        const SizedBox(width: 12),
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
                _updateCalculations();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: item.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            onChanged: (val) => _updateCalculations(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _removeLineItem(index),
          icon: const Icon(Icons.delete_outline),
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildTotalsSection() {
    final currencyFormat = NumberFormat.currency(symbol: r'$ ');
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildTotalRow('GST Total:',
                    currencyFormat.format(_totalGstCents / 100), false),
                const SizedBox(height: 8),
                _buildTotalRow('Invoice Total:',
                    currencyFormat.format(_totalCents / 100), true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, bool isMain) {
    final style = isMain
        ? Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.titleMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: style),
        const SizedBox(width: 24),
        SizedBox(
          width: 120,
          child: Text(value, style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildInvoiceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invoice History',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_invoices.isEmpty)
          const Text('No invoices yet.',
              style: TextStyle(color: Colors.black54))
        else
          _buildInvoiceTable(),
      ],
    );
  }

  Widget _buildInvoiceTable() {
    final currencyFormat = NumberFormat.currency(symbol: r'$');
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: FlexColumnWidth(),
        3: IntrinsicColumnWidth(),
        4: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
          children: const [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 16, 8),
              child: Text('Invoice #',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 16, 8),
              child: Text('Date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 16, 8),
              child: Text('Contact',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 16, 8),
              child: Text('Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: Text('Status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        for (final inv in _invoices)
          TableRow(
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200))),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                child: Text(inv.invoiceNumber,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                child: Text(inv.invoiceDate,
                    style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                child: Text(
                    _contactNames[inv.contactId] ?? inv.contactId,
                    style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                child: Text(
                    currencyFormat.format(inv.totalWithGstCents / 100),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                child: inv.isPaid
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                            horizontal: 8, vertical: 2),
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
            ],
          ),
      ],
    );
  }

  Future<void> _saveInvoice() async {
    if (_contactController.selectedContact == null && !_contactController.isNew) {
      _showError('Please select or create a contact.');
      return;
    }
    if (_contactController.isNew &&
        _contactController.nameController.text.isEmpty) {
      _showError('Please enter a name for the new contact.');
      return;
    }
    if (_invoiceNumberController.text.isEmpty) {
      _showError('Please enter an invoice number.');
      return;
    }

    for (var item in _lineItems) {
      if (item.glAccount == null) {
        _showError('All line items must have a GL account.');
        return;
      }
      if (item.amountCents <= 0) {
        _showError('All line items must have an amount greater than zero.');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final client = context.read<ApiClient>();

      // Create contact if new.
      String contactId;
      if (_contactController.isNew) {
        final contactBody = jsonEncode({
          'name': _contactController.nameController.text.trim(),
          'contactType': ContactType.company.name,
          'gstRegistered': _contactController.gstRegistered,
          'abn': _contactController.abnController.text.trim(),
        });
        final res = await client.post('/contacts', contactBody);
        if (res.statusCode != 201) {
          throw Exception('Failed to create contact: ${res.body}');
        }
        contactId = jsonDecode(res.body)['id'] as String;
      } else {
        contactId = _contactController.selectedContact!.id;
      }

      // Save invoice.
      final invoiceBody = jsonEncode({
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceDate': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        'contactId': contactId,
        'lineItems': _lineItems
            .map((item) => {
                  'description': item.descriptionController.text.trim(),
                  'generalLedgerId': item.glAccount!.id,
                  'amountCents': item.amountCents,
                  'gstCents': item.gstCents,
                })
            .toList(),
      });

      final res = await client.post('/invoices', invoiceBody);
      if (res.statusCode != 201) {
        final err = (jsonDecode(res.body) as Map?)?['error']?.toString() ??
            'Save failed (${res.statusCode})';
        throw Exception(err);
      }

      await _refreshInvoiceList();

      if (mounted) {
        setState(() => _saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invoice saved. Use Generate PDF to download.')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save invoice: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generatePdf() async {
    final currencyFormat = NumberFormat.currency(symbol: r'$');
    await InvoicePdf.generateAndDownload(
      entity: _entityDetails,
      contactName: _contactController.nameController.text.trim(),
      contactAbn: _contactController.abnController.text.trim(),
      contactGstRegistered: _contactController.gstRegistered,
      invoiceNumber: _invoiceNumberController.text.trim(),
      invoiceDate: _invoiceDate,
      lineItems: _lineItems,
      formatCents: (cents) => currencyFormat.format(cents / 100),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
