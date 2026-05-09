import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/gst_rate_entry.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';

class _GstRow {
  final String? id;
  final TextEditingController rateController; // percentage string, e.g. "10"
  DateTime? effectiveFrom;
  final bool isNew;
  final String _origRateStr;
  final DateTime? _origEffectiveFrom;

  _GstRow.fromEntry(GstRateEntry e)
      : id = e.id,
        effectiveFrom = e.effectiveFrom,
        isNew = false,
        _origRateStr = _rateToPercentage(e.rate),
        _origEffectiveFrom = e.effectiveFrom,
        rateController =
            TextEditingController(text: _rateToPercentage(e.rate));

  _GstRow.blank()
      : id = null,
        effectiveFrom = null,
        isNew = true,
        _origRateStr = '',
        _origEffectiveFrom = null,
        rateController = TextEditingController();

  // Converts 0.1 → "10", 0.125 → "12.50", avoiding float imprecision.
  static String _rateToPercentage(double rate) {
    final tenths = (rate * 10000).round(); // e.g. 0.1 → 1000
    if (tenths % 100 == 0) return (tenths ~/ 100).toString();
    return (tenths / 100).toStringAsFixed(2);
  }

  bool get isModified {
    if (isNew) return false;
    return rateController.text != _origRateStr ||
        !_sameDay(effectiveFrom, _origEffectiveFrom);
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void dispose() => rateController.dispose();
}

/// Displays the GST Rates screen with inline editing.
///
/// Rates are stored as decimals (0–1) on the server but shown as percentages
/// (0–100) in the UI. Changes are batched and sent on Save. Navigation is
/// blocked while unsaved changes exist.
class GstManagementScreen extends StatefulWidget {
  const GstManagementScreen({super.key});

  @override
  State<GstManagementScreen> createState() => _GstManagementScreenState();
}

class _GstManagementScreenState extends State<GstManagementScreen> {
  List<_GstRow> _rows = [];
  final Set<String> _pendingDeletions = {};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  bool _isDirty = false;

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
      final response = await context.read<ApiClient>().get('/gst-rates');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final entries = (jsonDecode(response.body) as List<dynamic>)
            .map((e) => GstRateEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final row in _rows) {
          row.dispose();
        }
        setState(() {
          _rows = entries.map(_GstRow.fromEntry).toList();
          _pendingDeletions.clear();
          _isDirty = false;
          _loading = false;
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

  void _markDirty() {
    if (_isDirty) return;
    setState(() => _isDirty = true);
    context.read<NavigationGuard>().setDirty(true);
  }

  void _addRow() {
    setState(() => _rows.add(_GstRow.blank()));
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

  Future<void> _pickDate(int index) async {
    final row = _rows[index];
    final initial = row.effectiveFrom ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select effective date',
    );
    if (picked != null && mounted) {
      setState(() => row.effectiveFrom = picked);
      _markDirty();
    }
  }

  Future<void> _discard() => _load();

  Future<void> _save() async {
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final rateStr = row.rateController.text.trim();
      if (rateStr.isEmpty) {
        _showSnackbar('Row ${i + 1}: rate must not be empty');
        return;
      }
      final rate = double.tryParse(rateStr);
      if (rate == null || rate < 0 || rate > 100) {
        _showSnackbar('Row ${i + 1}: rate must be a number between 0 and 100');
        return;
      }
      if (row.effectiveFrom == null) {
        _showSnackbar('Row ${i + 1}: effective from date must be selected');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final client = context.read<ApiClient>();

      for (final id in List<String>.from(_pendingDeletions)) {
        final res = await client.delete('/gst-rates/$id');
        if (res.statusCode != 204) {
          throw Exception('Delete failed (${res.statusCode})');
        }
        _pendingDeletions.remove(id);
      }

      for (final row in _rows) {
        if (!row.isNew && !row.isModified) continue;

        final body = jsonEncode({
          'rate': double.parse(row.rateController.text.trim()) / 100,
          'effectiveFrom': _isoDate(row.effectiveFrom!),
        });

        if (row.isNew) {
          final res = await client.post('/gst-rates', body);
          if (res.statusCode == 409) {
            throw Exception(_conflictMessage(res.body));
          }
          if (res.statusCode != 201) {
            throw Exception('Create failed (${res.statusCode})');
          }
        } else {
          final res = await client.put('/gst-rates/${row.id}', body);
          if (res.statusCode == 409) {
            throw Exception(_conflictMessage(res.body));
          }
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

  String _conflictMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'Duplicate effective date';
    } catch (_) {
      return 'Duplicate effective date';
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

  static String _isoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _displayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
    return Row(
      children: [
        Text(
          'GST Rates',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableHeader(),
        const Divider(height: 1),
        Expanded(
          child: _rows.isEmpty
              ? const Center(
                  child: Text('No rates yet. Use "Add rate" to create one.'),
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
            onPressed: _saving ? null : _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add rate'),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text('Rate (%)', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 200, child: Text('Effective From', style: style)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: TextFormField(
              controller: row.rateController,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                suffixText: '%',
              ),
              onChanged: (_) => _markDirty(),
            ),
          ),
          const SizedBox(width: 8),
          _buildDateCell(index),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _saving ? null : () => _deleteRow(index),
              tooltip: 'Delete',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(int index) {
    final row = _rows[index];
    final date = row.effectiveFrom;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _saving ? null : () => _pickDate(index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(
            color: _saving
                ? colorScheme.onSurface.withAlpha(61)
                : colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? _displayDate(date) : 'Select date',
                style: TextStyle(
                  color: date == null
                      ? colorScheme.onSurface.withAlpha(97)
                      : _saving
                          ? colorScheme.onSurface.withAlpha(97)
                          : null,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: _saving
                  ? colorScheme.onSurface.withAlpha(97)
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
