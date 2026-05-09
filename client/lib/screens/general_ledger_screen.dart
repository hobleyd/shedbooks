import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/general_ledger_entry.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';

/// A row in the editable general ledger table.
class _GlRow {
  final String? id;
  final TextEditingController labelController;
  final TextEditingController descriptionController;
  final FocusNode labelFocusNode;
  bool gstApplicable;
  GlDirection direction;
  final bool isNew;
  final String _origLabel;
  final String _origDescription;
  final bool _origGstApplicable;
  final GlDirection _origDirection;

  _GlRow.fromEntry(GeneralLedgerEntry e)
      : id = e.id,
        labelController = TextEditingController(text: e.label),
        descriptionController = TextEditingController(text: e.description),
        labelFocusNode = FocusNode(),
        gstApplicable = e.gstApplicable,
        direction = e.direction,
        isNew = false,
        _origLabel = e.label,
        _origDescription = e.description,
        _origGstApplicable = e.gstApplicable,
        _origDirection = e.direction;

  _GlRow.blank({required this.direction})
      : id = null,
        labelController = TextEditingController(),
        descriptionController = TextEditingController(),
        labelFocusNode = FocusNode(),
        gstApplicable = false,
        isNew = true,
        _origLabel = '',
        _origDescription = '',
        _origGstApplicable = false,
        _origDirection = direction;

  bool get isModified =>
      !isNew &&
      (labelController.text != _origLabel ||
          descriptionController.text != _origDescription ||
          gstApplicable != _origGstApplicable ||
          direction != _origDirection);

  void dispose() {
    labelController.dispose();
    descriptionController.dispose();
    labelFocusNode.dispose();
  }
}

/// Displays the General Ledger chart of accounts with inline editing,
/// split into Money In and Money Out tabs.
class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  List<_GlRow> _rows = [];
  final Set<String> _pendingDeletions = {};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  bool _isDirty = false;
  int? _sortColumn;
  bool _sortAscending = true;

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
    });
    try {
      final response = await context.read<ApiClient>().get('/general-ledger');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final entries = (jsonDecode(response.body) as List<dynamic>)
            .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final row in _rows) {
          row.dispose();
        }
        setState(() {
          _rows = entries.map(_GlRow.fromEntry).toList();
          _pendingDeletions.clear();
          _isDirty = false;
          _loading = false;
          _applySort();
        });
        context.read<NavigationGuard>().setDirty(false);
      } else {
        setState(() {
          _loadError = 'Failed to load (${response.statusCode})';
          _loading = false;
        });
      }
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
          cmp = a.labelController.text
              .toLowerCase()
              .compareTo(b.labelController.text.toLowerCase());
        case 1:
          cmp = a.descriptionController.text
              .toLowerCase()
              .compareTo(b.descriptionController.text.toLowerCase());
        case 2:
          cmp = (a.gstApplicable ? 1 : 0)
              .compareTo(b.gstApplicable ? 1 : 0);
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

  void _addRow(GlDirection direction) {
    final newRow = _GlRow.blank(direction: direction);
    setState(() => _rows.add(newRow));
    _markDirty();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => newRow.labelFocusNode.requestFocus(),
    );
  }

  void _deleteRow(_GlRow row) {
    setState(() {
      _rows.remove(row);
      if (!row.isNew && row.id != null) {
        _pendingDeletions.add(row.id!);
      }
      row.dispose();
    });
    _markDirty();
  }

  Future<void> _discard() => _load();

  Future<void> _save() async {
    for (int i = 0; i < _rows.length; i++) {
      if (_rows[i].labelController.text.trim().isEmpty) {
        _showSnackbar('Row ${i + 1}: label must not be empty');
        return;
      }
      if (_rows[i].descriptionController.text.trim().isEmpty) {
        _showSnackbar('Row ${i + 1}: description must not be empty');
        return;
      }
    }

    setState(() {
      _rows.sort((a, b) => a.labelController.text
          .trim()
          .toLowerCase()
          .compareTo(b.labelController.text.trim().toLowerCase()));
      _saving = true;
    });

    try {
      final client = context.read<ApiClient>();

      for (final id in List<String>.from(_pendingDeletions)) {
        final res = await client.delete('/general-ledger/$id');
        if (res.statusCode != 204) {
          throw Exception('Delete failed (${res.statusCode})');
        }
        _pendingDeletions.remove(id);
      }

      for (final row in _rows) {
        final body = jsonEncode({
          'label': row.labelController.text.trim(),
          'description': row.descriptionController.text.trim(),
          'gstApplicable': row.gstApplicable,
          'direction': row.direction == GlDirection.moneyIn ? 'moneyIn' : 'moneyOut',
        });
        if (row.isNew) {
          final res = await client.post('/general-ledger', body);
          if (res.statusCode != 201) {
            throw Exception('Create failed (${res.statusCode})');
          }
        } else if (row.isModified) {
          final res = await client.put('/general-ledger/${row.id}', body);
          if (res.statusCode != 200) {
            throw Exception('Update failed (${res.statusCode})');
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
    return DefaultTabController(
      length: 2,
      child: PopScope(
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
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Text(
          'General Ledger',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Spacer(),
        if (_isDirty && !_loading) ...[
          OutlinedButton(
            onPressed: _saving ? null : _discard,
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
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
            SelectableText(
              _loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Money In'),
            Tab(text: 'Money Out'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            children: [
              _buildTable(GlDirection.moneyIn),
              _buildTable(GlDirection.moneyOut),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(GlDirection direction) {
    final rows = _rows.where((r) => r.direction == direction).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('No entries yet. Use "Add entry" to create one.'),
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _buildTableRow(rows[i]),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : () => _addRow(direction),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            ),
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
          SizedBox(width: 220, child: _colHeader('Label', 0)),
          const SizedBox(width: 8),
          Expanded(child: _colHeader('Description', 1)),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: _colHeader('GST Applicable', 2,
                align: MainAxisAlignment.center),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(_GlRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextFormField(
              controller: row.labelController,
              focusNode: row.labelFocusNode,
              enabled: !_saving,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.descriptionController,
              enabled: !_saving,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: Center(
              child: Checkbox(
                value: row.gstApplicable,
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() => row.gstApplicable = v ?? false);
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
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _saving ? null : () => _deleteRow(row),
              tooltip: 'Delete',
            ),
          ),
        ],
      ),
    );
  }
}
