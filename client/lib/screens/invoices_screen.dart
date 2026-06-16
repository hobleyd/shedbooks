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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/invoice_line_item.dart';
import '../services/api_client.dart';
import '../widgets/contact_picker.dart';

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
  double _gstRate = 0.10; // Default to 10%
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
    for (var item in _lineItems) {
      item.updateAmounts(_gstRate);
    }
    setState(() {});
  }

  int get _totalCents => _lineItems.fold(0, (sum, item) => sum + item.amountCents);
  int get _totalGstCents => _lineItems.fold(0, (sum, item) => sum + item.gstCents);

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
                  labelText: 'Invoice / Receipt Number',
                  border: OutlineInputBorder(),
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
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<GeneralLedgerEntry>(
            initialValue: item.glAccount,
            decoration: const InputDecoration(
              labelText: 'GL Account',
              border: OutlineInputBorder(),
            ),
            items: _glAccounts.map((gl) {
              return DropdownMenuItem(
                value: gl,
                child: Text(gl.label, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
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

  Future<void> _saveInvoice() async {
    // Basic validation
    if (_contactController.selectedContact == null && !_contactController.isNew) {
      _showError('Please select or create a contact.');
      return;
    }
    if (_contactController.isNew && _contactController.nameController.text.isEmpty) {
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
      
      // 1. Handle new contact if necessary
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
        contactId = jsonDecode(res.body)['id'];
      } else {
        contactId = _contactController.selectedContact!.id;
      }

      // 2. Create transactions for each line item
      // Note: In a real system, we'd want this to be atomic on the backend.
      for (var item in _lineItems) {
        final txnBody = jsonEncode({
          'contactId': contactId,
          'generalLedgerId': item.glAccount!.id,
          'amount': item.amountCents,
          'gstAmount': item.gstCents,
          'transactionType': 'debit', // Invoices are usually outgoings/debits
          'receiptNumber': _invoiceNumberController.text.trim(),
          'transactionDate': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        });
        final res = await client.post('/transactions', txnBody);
        if (res.statusCode != 201) {
          throw Exception('Failed to create transaction for "${item.descriptionController.text}": ${res.body}');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully.')),
        );
        context.go('/transactions');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Failed to save invoice: $e');
      }
    }
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
