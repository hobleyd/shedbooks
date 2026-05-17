import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/locked_month_entry.dart';
import '../services/api_client.dart';

/// Admin screen for locking and unlocking financial months.
class LockedMonthsScreen extends StatefulWidget {
  const LockedMonthsScreen({super.key});

  @override
  State<LockedMonthsScreen> createState() => _LockedMonthsScreenState();
}

class _LockedMonthsScreenState extends State<LockedMonthsScreen> {
  bool _loading = true;
  String? _loadError;
  List<LockedMonthEntry> _locked = [];
  bool _saving = false;

  // Month picker state — default to previous month.
  late int _pickerYear;
  late int _pickerMonth;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    _pickerYear = prev.year;
    _pickerMonth = prev.month;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final res = await context.read<ApiClient>().get('/locked-months');
      if (res.statusCode != 200) {
        throw Exception('Server returned ${res.statusCode}');
      }
      final list = jsonDecode(res.body) as List<dynamic>;
      setState(() {
        _locked = list
            .map((j) => LockedMonthEntry.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  String get _pickerMonthYear =>
      '$_pickerYear-${_pickerMonth.toString().padLeft(2, '0')}';

  bool get _pickerAlreadyLocked =>
      _locked.any((m) => m.monthYear == _pickerMonthYear);

  Future<void> _lockMonth() async {
    setState(() => _saving = true);
    try {
      final res = await context.read<ApiClient>().post(
            '/locked-months',
            jsonEncode({'monthYear': _pickerMonthYear}),
          );
      if (res.statusCode != 204) {
        final msg =
            (jsonDecode(res.body) as Map?)?['error'] ?? res.statusCode.toString();
        throw Exception(msg);
      }
      await _load();
    } catch (e) {
      if (mounted) _showSnackbar('Failed to lock: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unlockMonth(LockedMonthEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock month?'),
        content: Text(
          'Unlocking ${_formatMonthYear(entry.monthYear)} will allow transactions '
          'in that period to be edited again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final res = await context
          .read<ApiClient>()
          .delete('/locked-months/${entry.monthYear}');
      if (res.statusCode != 204) {
        throw Exception('Server returned ${res.statusCode}');
      }
      await _load();
    } catch (e) {
      if (mounted) _showSnackbar('Failed to unlock: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static String _formatMonthYear(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length != 2) return monthYear;
    final month = int.tryParse(parts[1]) ?? 0;
    return '${_monthNames[month]} ${parts[0]}';
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = context.watch<AuthState>().isAdmin;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : _buildContent(isAdmin),
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

  Widget _buildContent(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Locked Months', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Locked months prevent any transactions in that period from being '
          'created, edited, or deleted. Only administrators can lock or unlock months.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        if (isAdmin) ...[
          _buildLockForm(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],
        Text('Locked Periods', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Expanded(child: _buildLockedList(isAdmin)),
      ],
    );
  }

  Widget _buildLockForm() {
    final now = DateTime.now();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lock a Month',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Month picker
                  SizedBox(
                    width: 160,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: DropdownButton<int>(
                        value: _pickerMonth,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(_monthNames[m],
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _pickerMonth = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Year picker
                  SizedBox(
                    width: 110,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: DropdownButton<int>(
                        value: _pickerYear,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: List.generate(6, (i) => now.year - 5 + i)
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('$y',
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _pickerYear = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _saving || _pickerAlreadyLocked ? null : _lockMonth,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_outlined, size: 16),
                    label: Text(_pickerAlreadyLocked ? 'Already locked' : 'Lock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedList(bool isAdmin) {
    if (_locked.isEmpty) {
      return const Center(
        child: Text('No months are currently locked.',
            style: TextStyle(color: Colors.black54)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView.separated(
        itemCount: _locked.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final entry = _locked[i];
          return ListTile(
            leading: const Icon(Icons.lock_outlined, color: Colors.orange),
            title: Text(_formatMonthYear(entry.monthYear),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('Locked on ${_formatDate(entry.lockedAt)}',
                style: const TextStyle(fontSize: 12)),
            trailing: isAdmin
                ? TextButton.icon(
                    onPressed: _saving ? null : () => _unlockMonth(entry),
                    icon: const Icon(Icons.lock_open_outlined, size: 16),
                    label: const Text('Unlock'),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error),
                  )
                : null,
          );
        },
      ),
    );
  }
}
