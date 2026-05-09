import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bank_account_entry.dart';
import '../services/api_client.dart';

/// Admin screen for managing bank accounts.
class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  bool _loading = true;
  String? _loadError;
  List<BankAccountEntry> _accounts = [];
  int? _sortColumn;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await context.read<ApiClient>().get('/bank-accounts');
      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final accounts = (jsonDecode(res.body) as List)
          .map((e) => BankAccountEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _accounts = accounts;
        _loading = false;
        _applySort();
      });
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
    _accounts.sort((a, b) {
      final int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.bankName.toLowerCase().compareTo(b.bankName.toLowerCase());
        case 1:
          cmp = a.accountName
              .toLowerCase()
              .compareTo(b.accountName.toLowerCase());
        case 2:
          cmp = a.bsb.compareTo(b.bsb);
        case 3:
          cmp = a.accountNumber.compareTo(b.accountNumber);
        case 4:
          cmp = a.accountTypeLabel.compareTo(b.accountTypeLabel);
        case 5:
          cmp = a.currency.compareTo(b.currency);
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

  Future<void> _openDialog({BankAccountEntry? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BankAccountDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(BankAccountEntry account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bank account?'),
        content: Text(
            'Remove ${account.accountName} (${account.bsbFormatted} / ${account.accountNumber})?'),
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
    if (confirmed != true) return;

    try {
      final res = await context
          .read<ApiClient>()
          .delete('/bank-accounts/${account.id}');
      if (!mounted) return;

      if (res.statusCode == 204) {
        _load();
      } else {
        String msg = 'Delete failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Delete failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bank Accounts',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (!_loading) ...[
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Bank Account'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            _buildError()
          else
            Expanded(child: _buildList()),
        ],
      ),
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

  Widget _buildList() {
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_outlined,
                size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text('No bank accounts configured.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Bank Account'),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                SizedBox(width: 180, child: _colHeader('Bank', 0)),
                SizedBox(width: 200, child: _colHeader('Account Name', 1)),
                SizedBox(width: 90, child: _colHeader('BSB', 2)),
                SizedBox(width: 120, child: _colHeader('Account No.', 3)),
                SizedBox(width: 110, child: _colHeader('Type', 4)),
                SizedBox(width: 60, child: _colHeader('Currency', 5)),
                const SizedBox(width: 80),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._accounts.map((a) => _buildRow(a)),
        ],
      ),
    );
  }

  Widget _buildRow(BankAccountEntry account) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 180,
                child: Text(account.bankName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 200,
                child: Text(account.accountName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 90,
                child: Text(account.bsbFormatted,
                    style: const TextStyle(fontFamily: 'monospace')),
              ),
              SizedBox(
                width: 120,
                child: Text(account.accountNumber,
                    style: const TextStyle(fontFamily: 'monospace')),
              ),
              SizedBox(
                width: 110,
                child: Text(account.accountTypeLabel,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              SizedBox(
                width: 60,
                child: Text(account.currency,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              SizedBox(
                width: 80,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      onPressed: () => _openDialog(existing: account),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.error),
                      tooltip: 'Delete',
                      onPressed: () => _delete(account),
                    ),
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
}

// ── Add / Edit dialog ──────────────────────────────────────────────────────────

class _BankAccountDialog extends StatefulWidget {
  final BankAccountEntry? existing;

  const _BankAccountDialog({this.existing});

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _accountNameCtrl;
  late final TextEditingController _bsbCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _currencyCtrl;
  late BankAccountType _accountType;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _bankNameCtrl = TextEditingController(text: e?.bankName ?? '');
    _accountNameCtrl = TextEditingController(text: e?.accountName ?? '');
    _bsbCtrl = TextEditingController(text: e?.bsb ?? '');
    _accountNumberCtrl = TextEditingController(text: e?.accountNumber ?? '');
    _currencyCtrl = TextEditingController(text: e?.currency ?? 'AUD');
    _accountType = e?.accountType ?? BankAccountType.transaction;
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNameCtrl.dispose();
    _bsbCtrl.dispose();
    _accountNumberCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final body = jsonEncode({
        'bankName': _bankNameCtrl.text.trim(),
        'accountName': _accountNameCtrl.text.trim(),
        'bsb': _bsbCtrl.text.replaceAll('-', '').trim(),
        'accountNumber': _accountNumberCtrl.text.trim(),
        'accountType': switch (_accountType) {
          BankAccountType.transaction => 'transaction',
          BankAccountType.savings => 'savings',
          BankAccountType.termDeposit => 'termDeposit',
        },
        'currency': _currencyCtrl.text.trim().toUpperCase(),
      });

      final client = context.read<ApiClient>();
      final res = _isEditing
          ? await client.put('/bank-accounts/${widget.existing!.id}', body)
          : await client.post('/bank-accounts', body);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.of(context).pop(true);
      } else {
        String msg = 'Save failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Bank Account' : 'Add Bank Account'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                label: 'Bank Name',
                controller: _bankNameCtrl,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Account Name',
                controller: _accountNameCtrl,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButton<BankAccountType>(
                  value: _accountType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                        value: BankAccountType.transaction,
                        child: Text('Transaction')),
                    DropdownMenuItem(
                        value: BankAccountType.savings,
                        child: Text('Savings')),
                    DropdownMenuItem(
                        value: BankAccountType.termDeposit,
                        child: Text('Term Deposit')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _accountType = v!),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(
                      label: 'BSB',
                      controller: _bsbCtrl,
                      hint: 'e.g. 062-000',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final digits =
                            (v ?? '').replaceAll('-', '').trim();
                        if (!RegExp(r'^\d{6}$').hasMatch(digits)) {
                          return 'Must be 6 digits';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _field(
                      label: 'Account Number',
                      controller: _accountNumberCtrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (!RegExp(r'^\d{6,10}$').hasMatch(s)) {
                          return '6–10 digits';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: _field(
                      label: 'Currency',
                      controller: _currencyCtrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (v) {
                        if (!RegExp(r'^[A-Za-z]{3}$')
                            .hasMatch((v ?? '').trim())) {
                          return '3 letters';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
