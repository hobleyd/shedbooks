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
import '../models/capex_request_entry.dart';
import '../models/invoice_entry.dart';
import '../models/permission_action.dart';
import '../models/permission_page.dart';
import '../services/api_client.dart';
import '../services/permission_service.dart';
import '../services/reference_data_cache.dart';

/// Capital Expenditure Requests screen — the club's paper CER form, digitised.
class CapexRequestsScreen extends StatefulWidget {
  const CapexRequestsScreen({super.key});

  @override
  State<CapexRequestsScreen> createState() => _CapexRequestsScreenState();
}

class _CapexRequestsScreenState extends State<CapexRequestsScreen> {
  bool _loading = true;
  String? _loadError;
  List<CapexRequestEntry> _requests = [];
  int? _sortColumn = 0;
  bool _sortAscending = false;

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
      final res = await context.read<ApiClient>().get('/capex-requests');
      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final requests = (jsonDecode(res.body) as List)
          .map((e) => CapexRequestEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _requests = requests;
        _applySort();
        _loading = false;
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
    _requests.sort((a, b) {
      // Executed date and invoice delta are optional — unset rows sort last
      // in either direction.
      if (_sortColumn == 6) return _compareNullsLast(a.executedDate, b.executedDate);
      if (_sortColumn == 7) {
        return _compareNullsLast(a.invoiceDeltaCents, b.invoiceDeltaCents);
      }
      final int cmp = switch (_sortColumn) {
        0 => a.requestNo.toLowerCase().compareTo(b.requestNo.toLowerCase()),
        1 => a.requestDate.compareTo(b.requestDate),
        2 => a.preparedByName
            .toLowerCase()
            .compareTo(b.preparedByName.toLowerCase()),
        3 => a.description.toLowerCase().compareTo(b.description.toLowerCase()),
        4 => a.totalAmountCents.compareTo(b.totalAmountCents),
        5 => a.status.compareTo(b.status),
        _ => 0,
      };
      return _sortAscending ? cmp : -cmp;
    });
  }

  int _compareNullsLast<T extends Comparable<Object>>(T? a, T? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final int cmp = a.compareTo(b);
    return _sortAscending ? cmp : -cmp;
  }

  void _onSort(int col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = col;
        _sortAscending = true;
      }
      _applySort();
    });
  }

  Future<void> _openDialog({CapexRequestEntry? existing}) async {
    final authState = context.read<AuthState>();
    final bool readOnly = existing != null && !_canEditEntry(existing);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CapexRequestDialog(
        existing: existing,
        readOnly: readOnly,
        defaultPreparedByName:
            authState.user?.name ?? authState.user?.email ?? '',
      ),
    );
    if (saved == true) _load();
  }

  /// Whether the current user may edit [entry]: page write access, plus the
  /// capex-edit-decided action once the request has been approved/rejected.
  bool _canEditEntry(CapexRequestEntry entry) {
    final PermissionService permissions = context.read<PermissionService>();
    if (!permissions.canWritePage(PermissionPage.capexRequests)) return false;
    return entry.isPending || permissions.canPerform(PermissionAction.capexEditDecided);
  }

  Future<void> _decide(CapexRequestEntry entry, String status) async {
    final authState = context.read<AuthState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DecisionDialog(
        entry: entry,
        status: status,
        defaultDecisionByName:
            authState.user?.name ?? authState.user?.email ?? '',
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _setExecutedDate(CapexRequestEntry entry) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExecutedDateDialog(entry: entry),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(CapexRequestEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete capex request?'),
        content: Text('Remove ${entry.requestNo} — ${entry.description}?'),
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
          .delete('/capex-requests/${entry.id}');
      if (!mounted) return;

      if (res.statusCode == 204) {
        _load();
      } else {
        String msg = 'Delete failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        _showSnackbar(msg);
      }
    } catch (e) {
      _showSnackbar('Delete failed: $e');
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<PermissionService>().canWritePage(PermissionPage.capexRequests);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Capital Expenditure Requests',
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
                  onPressed: canEdit ? () => _openDialog() : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Request'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_loadError != null)
            Expanded(child: _buildError())
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
    final permissions = context.watch<PermissionService>();
    final bool canApproveReject = permissions.canPerform(PermissionAction.capexApproveReject);
    final bool canEdit = permissions.canWritePage(PermissionPage.capexRequests);

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.request_quote_outlined,
                size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text('No capex requests recorded.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canEdit ? () => _openDialog() : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Request'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              _sortHeader('Request No', 0, width: 110),
              _sortHeader('Date', 1, width: 90),
              _sortHeader('Prepared By', 2, width: 140),
              _sortHeader('Description', 3),
              _sortHeader('Total', 4, width: 90, alignment: Alignment.centerRight),
              _sortHeader('Invoice', 7, width: 120, alignment: Alignment.centerRight),
              _sortHeader('Status', 5, width: 100, alignment: Alignment.center),
              _sortHeader('Executed', 6, width: 90, alignment: Alignment.center),
              const SizedBox(width: 232),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildRow(_requests[index],
                canApproveReject: canApproveReject, canEdit: canEdit),
          ),
        ),
      ],
    );
  }

  Widget _sortHeader(String label, int col,
      {double? width, Alignment alignment = Alignment.centerLeft}) {
    final isActive = _sortColumn == col;
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.bold);
    final mainAxisAlignment = switch (alignment) {
      Alignment.centerRight => MainAxisAlignment.end,
      Alignment.center => MainAxisAlignment.center,
      _ => MainAxisAlignment.start,
    };
    final content = InkWell(
      onTap: () => _onSort(col),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        children: [
          Flexible(
              child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
          if (isActive) ...[
            const SizedBox(width: 2),
            Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12),
          ],
        ],
      ),
    );
    return width != null ? SizedBox(width: width, child: content) : Expanded(child: content);
  }

  Widget _buildRow(CapexRequestEntry entry,
      {required bool canApproveReject, required bool canEdit}) {
    final bool canEditEntry = _canEditEntry(entry);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(entry.requestNo,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 90,
            child: Text(entry.requestDate,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          SizedBox(
            width: 140,
            child: Text(entry.preparedByName,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Text(entry.description,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatCents(entry.totalAmountCents),
                    style: Theme.of(context).textTheme.bodyMedium),
                if (entry.actualSpentCents != null)
                  Tooltip(
                    message: 'Actual amount spent',
                    child: Text('Spent ${_formatCents(entry.actualSpentCents!)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black54)),
                  ),
              ],
            ),
          ),
          SizedBox(width: 120, child: _invoiceCell(entry)),
          SizedBox(width: 100, child: Center(child: _statusChip(entry.status))),
          SizedBox(
            width: 90,
            child: Center(
              child: Text(entry.executedDate ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
          SizedBox(
            width: 232,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                      canEditEntry ? Icons.edit_outlined : Icons.visibility_outlined,
                      size: 18),
                  tooltip: canEditEntry ? 'Edit' : 'View',
                  onPressed: () => _openDialog(existing: entry),
                ),
                if (canApproveReject && entry.isPending) ...[
                  IconButton(
                    icon: Icon(Icons.check_circle_outline,
                        size: 18, color: Colors.green.shade700),
                    tooltip: 'Approve',
                    onPressed: () => _decide(entry, 'approved'),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel_outlined,
                        size: 18, color: Theme.of(context).colorScheme.error),
                    tooltip: 'Reject',
                    onPressed: () => _decide(entry, 'rejected'),
                  ),
                ],
                if (canEdit)
                  IconButton(
                    icon: Icon(Icons.event_available_outlined,
                        size: 18, color: Colors.blueGrey.shade700),
                    tooltip: entry.executedDate == null
                        ? 'Set Executed Date'
                        : 'Update Executed Date',
                    onPressed: () => _setExecutedDate(entry),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: canEdit
                          ? Theme.of(context).colorScheme.error
                          : Colors.black26),
                  tooltip: 'Delete',
                  onPressed: canEdit ? () => _delete(entry) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The linked invoice's number with, beneath it, the invoice total minus
  /// the amount spent — green when the invoice covers the spend, red when
  /// it falls short.
  Widget _invoiceCell(CapexRequestEntry entry) {
    final int? delta = entry.invoiceDeltaCents;
    if (delta == null) {
      return Text('—',
          textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium);
    }
    return Tooltip(
      message: 'Invoice ${_formatCents(entry.invoiceTotalCents!)} (incl. GST) '
          'less ${_formatCents(entry.amountSpentCents)} '
          '${entry.actualSpentCents != null ? 'spent' : 'requested (actual spend not recorded)'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(entry.invoiceNumber ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis),
          Text(_formatSignedCents(delta),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _deltaColor(delta), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'approved':
        color = Colors.green.shade700;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red.shade700;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange.shade800;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

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

/// [_formatCents] with an explicit sign, for an invoice-vs-spend delta.
String _formatSignedCents(int cents) =>
    '${cents < 0 ? '−' : '+'}${_formatCents(cents.abs())}';

Color _deltaColor(int deltaCents) =>
    deltaCents < 0 ? Colors.red.shade700 : Colors.green.shade700;

// ── Add / Edit / View dialog ────────────────────────────────────────────────

class _CapexRequestDialog extends StatefulWidget {
  final CapexRequestEntry? existing;
  final bool readOnly;
  final String defaultPreparedByName;

  const _CapexRequestDialog({
    this.existing,
    required this.readOnly,
    required this.defaultPreparedByName,
  });

  @override
  State<_CapexRequestDialog> createState() => _CapexRequestDialogState();
}

class _CapexRequestDialogState extends State<_CapexRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _totalEdited = false;
  bool _recomputingTotal = false;

  late final TextEditingController _requestNoCtrl;
  late final TextEditingController _preparedByCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _whatCtrl;
  late final TextEditingController _needCtrl;
  late final TextEditingController _alternativesCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _ongoingCtrl;
  late final TextEditingController _otherCtrl;
  late final TextEditingController _costNotesCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _quotesCtrl;
  late final TextEditingController _actualSpentCtrl;
  late DateTime _requestDate;
  String? _invoiceId;
  DateTime? _executedDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _requestNoCtrl = TextEditingController(text: e?.requestNo ?? '');
    _preparedByCtrl =
        TextEditingController(text: e?.preparedByName ?? widget.defaultPreparedByName);
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _whatCtrl = TextEditingController(text: e?.whatIsRequested ?? '');
    _needCtrl = TextEditingController(text: e?.needOrBenefit ?? '');
    _alternativesCtrl = TextEditingController(text: e?.alternativesConsidered ?? '');
    _purchaseCtrl = TextEditingController(
        text: e != null ? _centsToStr(e.purchaseCostCents) : '');
    _ongoingCtrl = TextEditingController(
        text: e?.ongoingCostsCents != null ? _centsToStr(e!.ongoingCostsCents!) : '');
    _otherCtrl = TextEditingController(
        text: e?.otherCostsCents != null ? _centsToStr(e!.otherCostsCents!) : '');
    _costNotesCtrl = TextEditingController(text: e?.costNotes ?? '');
    _totalCtrl =
        TextEditingController(text: e != null ? _centsToStr(e.totalAmountCents) : '');
    _quotesCtrl = TextEditingController(text: e?.quotesReceivedCount?.toString() ?? '');
    _actualSpentCtrl = TextEditingController(
        text: e?.actualSpentCents != null ? _centsToStr(e!.actualSpentCents!) : '');
    _requestDate = e != null ? DateTime.parse(e.requestDate) : DateTime.now();
    _invoiceId = e?.invoiceId;
    _executedDate = e?.executedDate != null ? DateTime.parse(e!.executedDate!) : null;
    _totalEdited = e != null;

    _purchaseCtrl.addListener(_recomputeTotal);
    _ongoingCtrl.addListener(_recomputeTotal);
    _otherCtrl.addListener(_recomputeTotal);
    _totalCtrl.addListener(() {
      if (!_recomputingTotal) _totalEdited = true;
      // The invoice delta shown under the picker depends on the total.
      if (_invoiceId != null && mounted) setState(() {});
    });
    // ...and on the actual amount spent, once that is entered.
    _actualSpentCtrl.addListener(() {
      if (_invoiceId != null && mounted) setState(() {});
    });

    if (!_isEditing) _fetchNextNumber();
    // The picker's options; skipped when it can't be used or the role
    // can't read invoices (the linked invoice's own details come with the
    // request, so it still displays).
    if (!widget.readOnly &&
        context.read<PermissionService>().canReadPage(PermissionPage.invoices)) {
      context.read<ReferenceDataCache>().refreshInvoices();
    }
  }

  @override
  void dispose() {
    _requestNoCtrl.dispose();
    _preparedByCtrl.dispose();
    _descriptionCtrl.dispose();
    _whatCtrl.dispose();
    _needCtrl.dispose();
    _alternativesCtrl.dispose();
    _purchaseCtrl.dispose();
    _ongoingCtrl.dispose();
    _otherCtrl.dispose();
    _costNotesCtrl.dispose();
    _totalCtrl.dispose();
    _quotesCtrl.dispose();
    _actualSpentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNextNumber() async {
    try {
      final res = await context.read<ApiClient>().get('/capex-requests/next-number');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _requestNoCtrl.text = data['requestNo'] as String);
      }
    } catch (_) {}
  }

  void _recomputeTotal() {
    if (_totalEdited) return;
    final sum = _parseDollarsToCents(_purchaseCtrl.text) +
        _parseDollarsToCents(_ongoingCtrl.text) +
        _parseDollarsToCents(_otherCtrl.text);
    _recomputingTotal = true;
    _totalCtrl.text = _centsToStr(sum);
    _recomputingTotal = false;
  }

  int _parseDollarsToCents(String s) {
    final d = double.tryParse(s.trim());
    if (d == null) return 0;
    return (d * 100).round();
  }

  String _centsToStr(int cents) => (cents / 100).toStringAsFixed(2);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final body = jsonEncode({
        'requestNo': _requestNoCtrl.text.trim(),
        'requestDate': DateFormat('yyyy-MM-dd').format(_requestDate),
        'preparedByName': _preparedByCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'whatIsRequested': _whatCtrl.text.trim(),
        'needOrBenefit': _needCtrl.text.trim(),
        'alternativesConsidered':
            _alternativesCtrl.text.trim().isEmpty ? null : _alternativesCtrl.text.trim(),
        'purchaseCostCents': _parseDollarsToCents(_purchaseCtrl.text),
        'ongoingCostsCents':
            _ongoingCtrl.text.trim().isEmpty ? null : _parseDollarsToCents(_ongoingCtrl.text),
        'otherCostsCents':
            _otherCtrl.text.trim().isEmpty ? null : _parseDollarsToCents(_otherCtrl.text),
        'costNotes': _costNotesCtrl.text.trim().isEmpty ? null : _costNotesCtrl.text.trim(),
        'totalAmountCents': _parseDollarsToCents(_totalCtrl.text),
        'quotesReceivedCount':
            _quotesCtrl.text.trim().isEmpty ? null : int.tryParse(_quotesCtrl.text.trim()),
        'invoiceId': _invoiceId,
      });

      final client = context.read<ApiClient>();
      final res = _isEditing
          ? await client.put('/capex-requests/${widget.existing!.id}', body)
          : await client.post('/capex-requests', body);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final String? executedDateError = await _saveExecutedDate(client);
        if (!mounted) return;
        if (executedDateError != null) _showSnackbar(executedDateError);
        Navigator.of(context).pop(true);
      } else {
        String msg = 'Save failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        setState(() => _saving = false);
        _showSnackbar(msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnackbar('Save failed: $e');
      }
    }
  }

  /// The actual amount spent as entered, or null when left blank.
  int? get _actualSpentCents => _actualSpentCtrl.text.trim().isEmpty
      ? null
      : _parseDollarsToCents(_actualSpentCtrl.text);

  /// Persists the executed date and actual amount spent when either was
  /// changed (or cleared) in this dialog. Returns an error message if that
  /// write fails, else null.
  Future<String?> _saveExecutedDate(ApiClient client) async {
    final CapexRequestEntry? e = widget.existing;
    if (e == null) return null;
    final String? executedDate =
        _executedDate == null ? null : DateFormat('yyyy-MM-dd').format(_executedDate!);
    final int? actualSpentCents = _actualSpentCents;
    if (executedDate == e.executedDate && actualSpentCents == e.actualSpentCents) {
      return null;
    }
    try {
      final res = await client.put(
          '/capex-requests/${e.id}/executed-date',
          jsonEncode(
              {'executedDate': executedDate, 'actualSpentCents': actualSpentCents}));
      if (res.statusCode == 200) return null;
      return 'Request saved, but the execution details were not updated (${res.statusCode})';
    } catch (err) {
      return 'Request saved, but the execution details were not updated: $err';
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// The GST-inclusive total of the selected invoice: from [invoices] when
  /// it's loaded, else from the request itself if the link is unchanged.
  int? _selectedInvoiceTotalCents(List<InvoiceEntry> invoices) {
    if (_invoiceId == null) return null;
    for (final InvoiceEntry invoice in invoices) {
      if (invoice.id == _invoiceId) return invoice.totalWithGstCents;
    }
    final CapexRequestEntry? e = widget.existing;
    return e?.invoiceId == _invoiceId ? e?.invoiceTotalCents : null;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;
    final List<InvoiceEntry> invoices = context.watch<ReferenceDataCache>().invoices;
    final title = !_isEditing
        ? 'New Capex Request'
        : (widget.readOnly ? 'View Capex Request' : 'Edit Capex Request');
    final disabled = _saving || widget.readOnly;

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e != null && !e.isPending) ...[
                  _decisionBanner(e),
                  const SizedBox(height: 14),
                ],
                if (e != null && !widget.readOnly) ...[
                  Row(
                    children: [
                      Expanded(child: _executedDateField(disabled)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _currencyField(
                          label: 'Actual Amount Spent',
                          controller: _actualSpentCtrl,
                          // Recorded with the execution, so needs a date.
                          enabled: !disabled && _executedDate != null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ] else if (e != null && e.executedDate != null) ...[
                  Row(
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 16, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 6),
                      Text(
                          'Executed on ${DateFormat('dd/MM/yyyy').format(DateTime.parse(e.executedDate!))}'
                          '${e.actualSpentCents != null ? ' — ${_formatCents(e.actualSpentCents!)} spent' : ''}'),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field(
                        label: 'Request No',
                        controller: _requestNoCtrl,
                        enabled: !disabled,
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _dateField(disabled),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'Prepared By',
                  controller: _preparedByCtrl,
                  enabled: !disabled,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'Description',
                  controller: _descriptionCtrl,
                  enabled: !disabled,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                Text('Asset Details', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                _field(
                  label: 'What is being requested?',
                  controller: _whatCtrl,
                  enabled: !disabled,
                  maxLines: 3,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'What need or benefit is being met?',
                  controller: _needCtrl,
                  enabled: !disabled,
                  maxLines: 3,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'Alternatives or options considered',
                  controller: _alternativesCtrl,
                  enabled: !disabled,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Text('Expenditure Details',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _currencyField(
                        label: 'Purchase Cost',
                        controller: _purchaseCtrl,
                        enabled: !disabled,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _currencyField(
                        label: 'Ongoing Service Costs',
                        controller: _ongoingCtrl,
                        enabled: !disabled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _currencyField(
                        label: 'Other Additional Costs',
                        controller: _otherCtrl,
                        enabled: !disabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'Cost notes (e.g. installation, freight)',
                  controller: _costNotesCtrl,
                  enabled: !disabled,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _currencyField(
                        label: 'Total Amount Being Requested',
                        controller: _totalCtrl,
                        enabled: !disabled,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        label: 'Quotes Received',
                        controller: _quotesCtrl,
                        enabled: !disabled,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _invoiceField(invoices, disabled),
                ..._invoiceDelta(invoices),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.readOnly ? 'Close' : 'Cancel'),
        ),
        if (!widget.readOnly)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? 'Update' : 'Create'),
          ),
      ],
    );
  }

  Widget _decisionBanner(CapexRequestEntry e) {
    final approved = e.isApproved;
    final color = approved ? Colors.green.shade800 : Colors.red.shade800;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(approved ? 'Approved' : 'Rejected',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              'By ${e.decisionByName ?? 'unknown'}'
              '${e.decisionAt != null ? ' on ${DateFormat('dd/MM/yyyy').format(DateTime.parse(e.decisionAt!).toLocal())}' : ''}'),
          if ((e.decisionNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(e.decisionNotes!),
          ],
        ],
      ),
    );
  }

  /// Optional link to an invoice raised to fund this request.
  Widget _invoiceField(List<InvoiceEntry> invoices, bool disabled) {
    final CapexRequestEntry? e = widget.existing;
    final bool selectedIsListed = invoices.any((i) => i.id == _invoiceId);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Linked Invoice (optional)',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: DropdownButton<String>(
        // '' stands for "no invoice" — DropdownButton treats a null value
        // as "nothing selected" and would show the hint instead.
        value: _invoiceId ?? '',
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem(value: '', child: Text('None')),
          // Keeps the current link selectable while invoices are still
          // loading (or when this role can't list them).
          if (_invoiceId != null && !selectedIsListed)
            DropdownMenuItem(
              value: _invoiceId,
              child: Text(e?.invoiceId == _invoiceId ? (e?.invoiceNumber ?? '') : ''),
            ),
          for (final InvoiceEntry invoice in invoices)
            DropdownMenuItem(
              value: invoice.id,
              child: Text(
                '${invoice.invoiceNumber} — '
                '${DateFormat('dd/MM/yyyy').format(DateTime.parse(invoice.invoiceDate))} — '
                '${_formatCents(invoice.totalWithGstCents)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: disabled
            ? null
            : (String? value) => setState(
                () => _invoiceId = (value == null || value.isEmpty) ? null : value),
      ),
    );
  }

  /// The linked invoice's total (incl. GST) minus the amount spent — the
  /// actual amount once entered, otherwise the total being requested; empty
  /// when no invoice is linked.
  List<Widget> _invoiceDelta(List<InvoiceEntry> invoices) {
    final int? invoiceTotalCents = _selectedInvoiceTotalCents(invoices);
    if (invoiceTotalCents == null) return const [];
    final bool spendRecorded = _actualSpentCents != null;
    final int delta = invoiceTotalCents -
        (_actualSpentCents ?? _parseDollarsToCents(_totalCtrl.text));
    final String amount = spendRecorded ? 'amount spent' : 'amount requested';
    final String summary = delta == 0
        ? 'Invoice covers the $amount exactly'
        : delta > 0
            ? 'Invoice exceeds the $amount by ${_formatCents(delta)}'
            : 'Invoice falls short of the $amount by ${_formatCents(-delta)}';
    return [
      const SizedBox(height: 6),
      Text(
        '$summary  (${_formatCents(invoiceTotalCents)} invoiced incl. GST)',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: _deltaColor(delta), fontWeight: FontWeight.w600),
      ),
    ];
  }

  /// Executed date with a clear control, so a date recorded by mistake can
  /// be removed while editing.
  Widget _executedDateField(bool disabled) {
    final bool hasValue = _executedDate != null;
    return InkWell(
      onTap: disabled
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _executedDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _executedDate = picked);
            },
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: const InputDecoration(
          labelText: 'Executed Date',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  hasValue ? DateFormat('dd/MM/yyyy').format(_executedDate!) : ''),
            ),
            Tooltip(
              message: hasValue ? 'Remove executed date' : '',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasValue && !disabled
                    ? () => setState(() {
                          _executedDate = null;
                          _actualSpentCtrl.clear();
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    hasValue ? Icons.clear : Icons.calendar_today_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(bool disabled) {
    return InkWell(
      onTap: disabled
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _requestDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _requestDate = picked);
            },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Request Date',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(_requestDate)),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _currencyField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: required
          ? (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: r'$ ',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

// ── Approve / reject decision dialog ────────────────────────────────────────

class _DecisionDialog extends StatefulWidget {
  final CapexRequestEntry entry;
  final String status; // 'approved' or 'rejected'
  final String defaultDecisionByName;

  const _DecisionDialog({
    required this.entry,
    required this.status,
    required this.defaultDecisionByName,
  });

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _byCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  bool get _approving => widget.status == 'approved';

  @override
  void initState() {
    super.initState();
    _byCtrl = TextEditingController(text: widget.defaultDecisionByName);
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _byCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = jsonEncode({
        'status': widget.status,
        'decisionByName': _byCtrl.text.trim(),
        'decisionNotes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      final res = await context
          .read<ApiClient>()
          .post('/capex-requests/${widget.entry.id}/decision', body);
      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        String msg = 'Failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_approving ? 'Approve Request' : 'Reject Request'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.entry.requestNo} — ${widget.entry.description}'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _byCtrl,
                enabled: !_saving,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                decoration: const InputDecoration(
                  labelText: 'Decision By',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  alignLabelWithHint: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
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
          style: FilledButton.styleFrom(
              backgroundColor:
                  _approving ? Colors.green.shade700 : Theme.of(context).colorScheme.error),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_approving ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}

// ── Set / clear executed date dialog ────────────────────────────────────────

class _ExecutedDateDialog extends StatefulWidget {
  final CapexRequestEntry entry;

  const _ExecutedDateDialog({required this.entry});

  @override
  State<_ExecutedDateDialog> createState() => _ExecutedDateDialogState();
}

class _ExecutedDateDialogState extends State<_ExecutedDateDialog> {
  DateTime? _executedDate;
  late final TextEditingController _actualSpentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _executedDate = widget.entry.executedDate != null
        ? DateTime.parse(widget.entry.executedDate!)
        : null;
    final int? actualSpentCents = widget.entry.actualSpentCents;
    _actualSpentCtrl = TextEditingController(
        text: actualSpentCents == null ? '' : (actualSpentCents / 100).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _actualSpentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _executedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _executedDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final double? actualSpent = double.tryParse(_actualSpentCtrl.text.trim());
    try {
      final body = jsonEncode({
        'executedDate': _executedDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_executedDate!),
        'actualSpentCents': _executedDate == null || actualSpent == null
            ? null
            : (actualSpent * 100).round(),
      });
      final res = await context
          .read<ApiClient>()
          .put('/capex-requests/${widget.entry.id}/executed-date', body);
      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        String msg = 'Failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Executed Date'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.entry.requestNo} — ${widget.entry.description}'),
            const SizedBox(height: 14),
            InkWell(
              onTap: _saving ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Executed Date',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                child: Text(_executedDate == null
                    ? 'Not set'
                    : DateFormat('dd/MM/yyyy').format(_executedDate!)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _actualSpentCtrl,
              // Recorded with the execution, so needs a date.
              enabled: !_saving && _executedDate != null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Actual Amount Spent (optional)',
                helperText:
                    'Requested: ${(widget.entry.totalAmountCents / 100).toStringAsFixed(2)}',
                prefixText: r'$ ',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_executedDate != null)
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _executedDate = null;
                      _actualSpentCtrl.clear();
                    }),
            child: const Text('Clear'),
          ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
