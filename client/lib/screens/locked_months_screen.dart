import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/bank_account_entry.dart';
import '../models/locked_month_entry.dart';
import '../services/api_client.dart';

/// Admin screen for locking and unlocking financial months per bank account.
class LockedMonthsScreen extends StatefulWidget {
  const LockedMonthsScreen({super.key});

  @override
  State<LockedMonthsScreen> createState() => _LockedMonthsScreenState();
}

class _LockedMonthsScreenState extends State<LockedMonthsScreen> {
  bool _loading = true;
  String? _loadError;

  List<BankAccountEntry> _bankAccounts = [];

  /// Keyed by monthYear → bankAccountId → entry.
  Map<String, Map<String, LockedMonthEntry>> _lockedMap = {};

  bool _saving = false;

  // Month picker state — default to previous month.
  late int _pickerYear;
  late int _pickerMonth;
  String? _pickerBankAccountId;

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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/bank-accounts'),
        client.get('/locked-months'),
      ]);

      final accountsRes = results[0];
      final lockedRes = results[1];

      if (accountsRes.statusCode != 200) {
        throw Exception('Loading bank accounts failed (${accountsRes.statusCode})');
      }
      if (lockedRes.statusCode != 200) {
        throw Exception('Loading locked months failed (${lockedRes.statusCode})');
      }

      final accounts = (jsonDecode(accountsRes.body) as List<dynamic>)
          .map((j) => BankAccountEntry.fromJson(j as Map<String, dynamic>))
          .toList();

      final locked = (jsonDecode(lockedRes.body) as List<dynamic>)
          .map((j) => LockedMonthEntry.fromJson(j as Map<String, dynamic>))
          .toList();

      final map = <String, Map<String, LockedMonthEntry>>{};
      for (final entry in locked) {
        map.putIfAbsent(entry.monthYear, () => {})[entry.bankAccountId] = entry;
      }

      setState(() {
        _bankAccounts = accounts;
        _lockedMap = map;
        _pickerBankAccountId ??= accounts.isNotEmpty ? accounts.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  String get _pickerMonthYear =>
      '$_pickerYear-${_pickerMonth.toString().padLeft(2, '0')}';

  bool get _pickerAlreadyLocked =>
      _pickerBankAccountId != null &&
      (_lockedMap[_pickerMonthYear]?.containsKey(_pickerBankAccountId) ??
          false);

  Future<void> _lockMonth() async {
    if (_pickerBankAccountId == null) return;
    setState(() => _saving = true);
    try {
      final res = await context.read<ApiClient>().post(
            '/locked-months',
            jsonEncode({
              'monthYear': _pickerMonthYear,
              'bankAccountId': _pickerBankAccountId,
            }),
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

  Future<void> _unlockMonth(String monthYear, String bankAccountId) async {
    final accountName = _bankAccounts
        .firstWhere((a) => a.id == bankAccountId,
            orElse: () => BankAccountEntry(
                  id: bankAccountId,
                  bankName: '',
                  accountName: 'account',
                  bsb: '',
                  accountNumber: '',
                  accountType: BankAccountType.transaction,
                  currency: '',
                ))
        .accountName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock month?'),
        content: Text(
          'Unlocking ${_formatMonthYear(monthYear)} for $accountName will allow '
          'transactions in that period to be edited again.',
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
          .delete('/locked-months/$monthYear/$bankAccountId');
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
          'created, edited, or deleted. Each bank account can be locked independently. '
          'Only administrators can lock or unlock months.',
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
        Expanded(child: _buildLockedTable(isAdmin)),
      ],
    );
  }

  Widget _buildLockForm() {
    final now = DateTime.now();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lock a Month',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  // Bank account picker
                  if (_bankAccounts.isNotEmpty)
                    SizedBox(
                      width: 200,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Bank Account',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        child: DropdownButton<String>(
                          value: _pickerBankAccountId,
                          isExpanded: true,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: _bankAccounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.accountName,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) =>
                                  setState(() => _pickerBankAccountId = v),
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _saving ||
                            _pickerAlreadyLocked ||
                            _pickerBankAccountId == null
                        ? null
                        : _lockMonth,
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

  Widget _buildLockedTable(bool isAdmin) {
    if (_bankAccounts.isEmpty) {
      return const Center(
        child: Text('No bank accounts found.',
            style: TextStyle(color: Colors.black54)),
      );
    }

    // Collect all distinct months across all locks, sorted descending.
    final months = _lockedMap.keys.toList()..sort((a, b) => b.compareTo(a));

    if (months.isEmpty) {
      return const Center(
        child: Text('No months are currently locked.',
            style: TextStyle(color: Colors.black54)),
      );
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.surfaceContainerHighest),
          columns: [
            const DataColumn(label: Text('Month')),
            ..._bankAccounts.map(
              (a) => DataColumn(
                label: Text(a.accountName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          rows: months.map((monthYear) {
            final locksByAccount = _lockedMap[monthYear] ?? {};
            return DataRow(
              cells: [
                DataCell(Text(_formatMonthYear(monthYear),
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                ..._bankAccounts.map((account) {
                  final entry = locksByAccount[account.id];
                  if (entry == null) {
                    return const DataCell(SizedBox.shrink());
                  }
                  return DataCell(
                    Center(
                      child: isAdmin
                          ? IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => _unlockMonth(monthYear, account.id),
                              icon: const Icon(Icons.lock_open_outlined,
                                  size: 16),
                              color: Theme.of(context).colorScheme.error,
                              tooltip: 'Unlock',
                            )
                          : const Icon(Icons.lock_outlined,
                              size: 16, color: Colors.orange),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
