import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/contact_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';

enum _AbnLookupState { idle, loading, found, notFound, error }

class _ContactRow {
  final String? id;
  final TextEditingController nameController;
  final TextEditingController abnController;
  final TextEditingController bsbController;
  final TextEditingController accountNumberController;
  ContactType contactType;
  bool gstRegistered;
  _AbnLookupState abnLookupState;
  final bool isNew;
  final String _origName;
  final String? _origAbn;
  final String? _origBsb;
  final String? _origAccountNumber;
  final ContactType _origContactType;
  final bool _origGstRegistered;

  _ContactRow.fromEntry(ContactEntry e)
      : id = e.id,
        nameController = TextEditingController(text: e.name),
        abnController = TextEditingController(text: e.abn ?? ''),
        bsbController = TextEditingController(text: e.bsb ?? ''),
        accountNumberController = TextEditingController(text: e.accountNumber ?? ''),
        contactType = e.contactType,
        gstRegistered = e.gstRegistered,
        abnLookupState = _AbnLookupState.idle,
        isNew = false,
        _origName = e.name,
        _origAbn = e.abn,
        _origBsb = e.bsb,
        _origAccountNumber = e.accountNumber,
        _origContactType = e.contactType,
        _origGstRegistered = e.gstRegistered;

  _ContactRow.blank()
      : id = null,
        nameController = TextEditingController(),
        abnController = TextEditingController(),
        bsbController = TextEditingController(),
        accountNumberController = TextEditingController(),
        contactType = ContactType.person,
        gstRegistered = false,
        abnLookupState = _AbnLookupState.idle,
        isNew = true,
        _origName = '',
        _origAbn = null,
        _origBsb = null,
        _origAccountNumber = null,
        _origContactType = ContactType.person,
        _origGstRegistered = false;

  bool get isModified {
    if (isNew) return false;
    return nameController.text != _origName ||
        abnController.text != (_origAbn ?? '') ||
        bsbController.text != (_origBsb ?? '') ||
        accountNumberController.text != (_origAccountNumber ?? '') ||
        contactType != _origContactType ||
        gstRegistered != _origGstRegistered;
  }

  void dispose() {
    nameController.dispose();
    abnController.dispose();
    bsbController.dispose();
    accountNumberController.dispose();
  }
}

/// Displays the Contacts screen with inline editing.
///
/// Changes are batched and sent on Save. Navigation is blocked while
/// unsaved changes exist.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<_ContactRow> _rows = [];
  final Set<String> _pendingDeletions = {};
  bool _loading = true;
  bool _saving = false;
  bool _merging = false;
  String? _loadError;
  bool _isDirty = false;
  int? _sortColumn;
  bool _sortAscending = true;
  final Set<String> _selectedIds = {};
  Set<String> _contactsWithTransactions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    context.read<NavigationGuard>().setDirty(false);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _saving = false;
      _merging = false;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/contacts'),
        client.get('/transactions'),
      ]);
      if (!mounted) return;

      if (results[0].statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load (${results[0].statusCode})';
          _loading = false;
        });
        return;
      }

      final entries = (jsonDecode(results[0].body) as List<dynamic>)
          .map((e) => ContactEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final contactsWithTxns = <String>{};
      if (results[1].statusCode == 200) {
        final txns = (jsonDecode(results[1].body) as List<dynamic>)
            .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>));
        for (final t in txns) {
          contactsWithTxns.add(t.contactId);
        }
      }

      for (final row in _rows) {
        row.dispose();
      }
      setState(() {
        _rows = entries.map(_ContactRow.fromEntry).toList();
        _pendingDeletions.clear();
        _selectedIds.clear();
        _contactsWithTransactions = contactsWithTxns;
        _isDirty = false;
        _loading = false;
        _applySort();
      });
      context.read<NavigationGuard>().setDirty(false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  void _applySort() {
    if (_sortColumn == null) return;
    _rows.sort((a, b) {
      final int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.nameController.text
              .toLowerCase()
              .compareTo(b.nameController.text.toLowerCase());
        case 1:
          cmp = a.abnController.text.compareTo(b.abnController.text);
        case 2:
          cmp = a.contactType.name.compareTo(b.contactType.name);
        case 3:
          cmp = (a.gstRegistered ? 1 : 0).compareTo(b.gstRegistered ? 1 : 0);
        case 4:
          cmp = a.bsbController.text.compareTo(b.bsbController.text);
        case 5:
          cmp = a.accountNumberController.text
              .compareTo(b.accountNumberController.text);
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

  void _markDirty() {
    if (_isDirty) return;
    setState(() => _isDirty = true);
    context.read<NavigationGuard>().setDirty(true);
  }

  void _addRow() {
    setState(() => _rows.add(_ContactRow.blank()));
    _markDirty();
  }

  void _deleteRow(int index) {
    setState(() {
      final row = _rows.removeAt(index);
      if (!row.isNew && row.id != null) {
        _pendingDeletions.add(row.id!);
      }
      row.dispose();
    });
    _markDirty();
  }

  Future<void> _lookupAbn(_ContactRow row) async {
    final abn = row.abnController.text.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(abn)) return;

    setState(() => row.abnLookupState = _AbnLookupState.loading);

    try {
      final res =
          await context.read<ApiClient>().get('/abn-lookup?abn=$abn');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final found = data['found'] as bool;
        if (!found) {
          setState(() => row.abnLookupState = _AbnLookupState.notFound);
          return;
        }
        setState(() {
          row.gstRegistered = data['gstRegistered'] as bool;
          row.abnLookupState = _AbnLookupState.found;
        });
        _markDirty();
      } else {
        setState(() => row.abnLookupState = _AbnLookupState.error);
      }
    } catch (_) {
      if (mounted) setState(() => row.abnLookupState = _AbnLookupState.error);
    }
  }

  Future<void> _discard() => _load();

  Future<void> _save() async {
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.nameController.text.trim().isEmpty) {
        _showSnackbar('Row ${i + 1}: name must not be empty');
        return;
      }
      if (row.contactType == ContactType.company) {
        final abn = row.abnController.text.trim();
        if (!RegExp(r'^\d{11}$').hasMatch(abn)) {
          _showSnackbar('Row ${i + 1}: ABN must be 11 digits for a company');
          return;
        }
      }
    }

    setState(() => _saving = true);

    try {
      final client = context.read<ApiClient>();

      for (final id in List<String>.from(_pendingDeletions)) {
        final res = await client.delete('/contacts/$id');
        if (res.statusCode != 204) {
          throw Exception(
              _errorMessage(res.body, 'Delete failed (${res.statusCode})'));
        }
        _pendingDeletions.remove(id);
      }

      for (final row in _rows) {
        if (!row.isNew && !row.isModified) continue;

        final isCompany = row.contactType == ContactType.company;
        final body = jsonEncode({
          'name': row.nameController.text.trim(),
          'contactType': row.contactType.name,
          'gstRegistered': row.gstRegistered,
          if (isCompany) 'abn': row.abnController.text.trim(),
          'bsb': row.bsbController.text.replaceAll('-', '').trim(),
          'accountNumber': row.accountNumberController.text.trim(),
        });

        if (row.isNew) {
          final res = await client.post('/contacts', body);
          if (res.statusCode != 201) {
            throw Exception(
                _errorMessage(res.body, 'Create failed (${res.statusCode})'));
          }
        } else {
          final res = await client.put('/contacts/${row.id}', body);
          if (res.statusCode != 200) {
            throw Exception(
                _errorMessage(res.body, 'Update failed (${res.statusCode})'));
          }
        }
      }

      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnackbar('Save failed: $e');
      }
    }
  }

  String _errorMessage(String body, String fallback) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _mergeContacts() async {
    if (_selectedIds.length < 2) return;

    // Preserve current list order: first selected row is the survivor.
    final ordered = _rows
        .where((r) => r.id != null && _selectedIds.contains(r.id))
        .toList();
    final keepId = ordered.first.id!;
    final keepName = ordered.first.nameController.text;
    final mergeIds = ordered.skip(1).map((r) => r.id!).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge contacts'),
        content: Text(
          '${mergeIds.length} contact${mergeIds.length == 1 ? '' : 's'} will be '
          'merged into "$keepName". All their transactions will be reassigned '
          'and the other contact${mergeIds.length == 1 ? '' : 's'} deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _merging = true);

    try {
      final body = jsonEncode({'keepId': keepId, 'mergeIds': mergeIds});
      final res = await context.read<ApiClient>().post('/contacts/merge', body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        await _load();
      } else {
        setState(() => _merging = false);
        _showSnackbar(_errorMessage(res.body, 'Merge failed (${res.statusCode})'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _merging = false);
        _showSnackbar('Merge failed: $e');
      }
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && mounted) {
          context.read<NavigationGuard>().setDirty(false);
          context.pop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleRow(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    final busy = _saving || _merging;
    final bool canEdit = context.watch<AuthState>().canEdit;
    return Row(
      children: [
        Text('Contacts', style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        if (_selectedIds.length >= 2 && canEdit) ...[
          FilledButton.icon(
            onPressed: busy ? null : _mergeContacts,
            icon: _merging
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.merge_outlined, size: 18),
            label: Text('Merge ${_selectedIds.length}'),
          ),
          const SizedBox(width: 8),
        ],
        if (_isDirty && !_loading && canEdit) ...[
          OutlinedButton(
            onPressed: busy ? null : _discard,
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return _buildTable();
  }

  Widget _buildTable() {
    final bool canEdit = context.watch<AuthState>().canEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableHeader(),
        const Divider(height: 1),
        Expanded(
          child: _rows.isEmpty
              ? const Center(
                  child: Text('No contacts yet. Use "Add contact" to create one.'),
                )
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _buildTableRow(i),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton.icon(
            onPressed: (_saving || !canEdit) ? null : _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add contact'),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(child: _colHeader('Name', 0)),
          const SizedBox(width: 8),
          SizedBox(width: 130, child: _colHeader('ABN', 1)),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: _colHeader('BSB', 4)),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: _colHeader('Account No.', 5)),
          const SizedBox(width: 8),
          SizedBox(width: 160, child: _colHeader('Type', 2)),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: _colHeader('GST Registered', 3,
                align: MainAxisAlignment.center),
          ),
          const SizedBox(width: 48), // delete
          const SizedBox(width: 40), // view transactions
        ],
      ),
    );
  }

  Widget _buildTableRow(int index) {
    final row = _rows[index];
    final isCompany = row.contactType == ContactType.company;
    final isSelected = row.id != null && _selectedIds.contains(row.id);
    final hasTxns = row.id != null && _contactsWithTransactions.contains(row.id);
    final busy = _saving || _merging;
    final bool canEdit = context.watch<AuthState>().canEdit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isSelected,
              onChanged: (row.id == null || busy)
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selectedIds.add(row.id!);
                        } else {
                          _selectedIds.remove(row.id!);
                        }
                      }),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: row.nameController,
              enabled: !_saving && canEdit,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(width: 8),
          _buildAbnField(row, isCompany),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: row.bsbController,
              enabled: !_saving && canEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                hintText: 'XXX-XXX',
              ),
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: row.accountNumberController,
              enabled: !_saving && canEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              child: DropdownButton<ContactType>(
                value: row.contactType,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: ContactType.person,
                    child: Text('Person'),
                  ),
                  DropdownMenuItem(
                    value: ContactType.company,
                    child: Text('Company'),
                  ),
                ],
                onChanged: (_saving || !canEdit)
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          row.contactType = value;
                          if (value == ContactType.person) {
                            row.gstRegistered = false;
                            row.abnController.clear();
                            row.abnLookupState = _AbnLookupState.idle;
                          }
                        });
                        _markDirty();
                      },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: Center(
              child: Checkbox(
                value: row.gstRegistered,
                onChanged: (_saving || !isCompany || !canEdit)
                    ? null
                    : (v) {
                        setState(() => row.gstRegistered = v ?? false);
                        _markDirty();
                      },
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: hasTxns
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38)
                    : Theme.of(context).colorScheme.error,
              ),
              onPressed: (busy || hasTxns || !canEdit) ? null : () => _deleteRow(index),
              tooltip: hasTxns
                  ? 'Cannot delete: contact has transactions'
                  : 'Delete',
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: (row.id == null || _isDirty)
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                    : Theme.of(context).colorScheme.primary,
              ),
              onPressed: (row.id == null || _isDirty)
                  ? null
                  : () {
                      final contact = ContactEntry(
                        id: row.id!,
                        name: row.nameController.text,
                        contactType: row.contactType,
                        gstRegistered: row.gstRegistered,
                        abn: row.contactType == ContactType.company
                            ? row.abnController.text.trim()
                            : null,
                      );
                      context.go('/transactions', extra: contact);
                    },
              tooltip: _isDirty
                  ? 'Save or discard changes first'
                  : 'View transactions',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbnField(_ContactRow row, bool isCompany) {
    final bool canEdit = context.watch<AuthState>().canEdit;
    Widget? suffixIcon;
    switch (row.abnLookupState) {
      case _AbnLookupState.loading:
        suffixIcon = const Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _AbnLookupState.found:
        suffixIcon = const Icon(Icons.check_circle_outline,
            color: Colors.green, size: 18);
      case _AbnLookupState.notFound:
        suffixIcon = Icon(Icons.cancel_outlined,
            color: Theme.of(context).colorScheme.error, size: 18);
      case _AbnLookupState.error:
        suffixIcon = const Icon(Icons.warning_amber_outlined,
            color: Colors.orange, size: 18);
      case _AbnLookupState.idle:
        suffixIcon = null;
    }

    return SizedBox(
      width: 130,
      child: TextFormField(
        controller: row.abnController,
        enabled: !_saving && isCompany && canEdit,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        onChanged: (isCompany && canEdit)
            ? (value) {
                setState(() => row.abnLookupState = _AbnLookupState.idle);
                _markDirty();
                if (value.length == 11) _lookupAbn(row);
              }
            : null,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
          hintText: isCompany ? '11 digits' : '—',
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
