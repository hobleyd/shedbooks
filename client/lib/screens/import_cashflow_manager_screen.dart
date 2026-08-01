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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';
import '../services/reference_data_cache.dart';
import '../utils/cashflow_manager_parser.dart';

/// Auto-created (find-or-create) contact used for every transaction created
/// by this importer. CashFlow Manager's narrative text mixes payer/payee
/// names with bank boilerplate too inconsistently to reliably extract a
/// real contact — imported transactions land against this placeholder and
/// can be reassigned individually afterwards via the normal edit flow.
const _importContactName = 'CashFlow Manager Import';

/// A code needing user attention: either never seen before, or seen but
/// only fuzzy-matched below the auto-accept confidence threshold.
class _UnresolvedCode {
  final String code;
  final String sampleName;
  final int occurrences;
  final int totalGrossCents;

  /// Best-effort direction from the export's own columns (see
  /// [CashflowManagerRow.guessedDirection]). Filters the GL dropdown, but
  /// stays user-editable in the dialog in case the guess is wrong.
  GlDirection direction;
  String? selectedGlId;

  _UnresolvedCode({
    required this.code,
    required this.sampleName,
    required this.occurrences,
    required this.totalGrossCents,
    required this.direction,
    this.selectedGlId,
  });
}

/// Full-page import flow for a CashFlow Manager "Transaction Listing" CSV
/// export. GL codes/descriptions embedded in the export are matched to this
/// entity's chart of accounts; codes that can't be matched confidently are
/// prompted for once and the choice is kept in [ReferenceDataCache] for the
/// rest of the session so re-importing the same or an updated file does not
/// re-prompt for codes already resolved.
class ImportCashflowManagerScreen extends StatefulWidget {
  const ImportCashflowManagerScreen({super.key});

  @override
  State<ImportCashflowManagerScreen> createState() =>
      _ImportCashflowManagerScreenState();
}

class _ImportCashflowManagerScreenState
    extends State<ImportCashflowManagerScreen> {
  bool _loading = true;
  String? _loadError;

  String? _fileName;
  List<CashflowManagerRow> _rows = [];
  bool _matching = false;

  bool _saving = false;
  String? _saveStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cache = context.read<ReferenceDataCache>();
      await Future.wait([
        cache.ensureGlLoaded(),
        cache.ensureContactsLoaded(),
      ]);
      if (!mounted) return;
      if (cache.glStatus == LoadStatus.error) {
        setState(() {
          _loadError = cache.glError ?? 'Failed to load GL accounts';
          _loading = false;
        });
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  // ── File picking & parsing ───────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    List<CashflowManagerRow> rows;
    try {
      final content = decodeCashflowManagerCsvBytes(bytes);
      rows = parseCashflowManagerCsv(content);
    } catch (e) {
      _showSnackbar('Failed to parse file: $e');
      return;
    }

    if (rows.isEmpty) {
      _showSnackbar('No transactions found in this file.');
      return;
    }

    setState(() {
      _fileName = file.name;
      _rows = rows;
    });
    await _matchAndMaybePrompt();
  }

  // ── GL matching ──────────────────────────────────────────────────────────────

  /// Resolves every unique GL code in [_rows] against the session mapping
  /// cache and fuzzy description matching, prompting the user once per code
  /// that isn't already resolved and can't be matched with confidence.
  Future<void> _matchAndMaybePrompt() async {
    final cache = context.read<ReferenceDataCache>();
    final glEntries = cache.glEntries;
    final sessionMap = cache.cashflowManagerGlMappings;

    final unresolved = <String, _UnresolvedCode>{};

    for (final row in _rows) {
      if (sessionMap.containsKey(row.externalCode)) continue;
      if (unresolved.containsKey(row.externalCode)) {
        final existing = unresolved[row.externalCode]!;
        unresolved[row.externalCode] = _UnresolvedCode(
          code: existing.code,
          sampleName: existing.sampleName,
          occurrences: existing.occurrences + 1,
          totalGrossCents: existing.totalGrossCents + row.grossCents,
          direction: existing.direction,
          selectedGlId: existing.selectedGlId,
        );
        continue;
      }

      final match = fuzzyMatchGlAccount(row.externalName, glEntries,
          direction: row.guessedDirection);
      if (match.isConfident && match.glId != null) {
        cache.setCashflowManagerGlMapping(row.externalCode, match.glId!);
        continue;
      }

      unresolved[row.externalCode] = _UnresolvedCode(
        code: row.externalCode,
        sampleName: row.externalName,
        occurrences: 1,
        totalGrossCents: row.grossCents,
        direction: row.guessedDirection,
        selectedGlId: match.glId,
      );
    }

    if (unresolved.isNotEmpty) {
      setState(() => _matching = true);
      final resolved = await showDialog<Map<String, String?>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GlMappingDialog(
          codes: unresolved.values.toList()
            ..sort((a, b) => a.code.compareTo(b.code)),
          glEntries: glEntries,
        ),
      );
      if (!mounted) return;
      if (resolved != null) {
        for (final entry in resolved.entries) {
          if (entry.value != null) {
            cache.setCashflowManagerGlMapping(entry.key, entry.value!);
          }
        }
      }
      setState(() => _matching = false);
    } else {
      setState(() {});
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────────

  // Rebuilds of this screen are already driven by explicit setState() calls
  // after the cache is mutated (see _matchAndMaybePrompt), so this reads
  // rather than watches — it's also called from _save(), outside of build,
  // where context.watch would throw.
  Map<String, String> get _codeToGl =>
      context.read<ReferenceDataCache>().cashflowManagerGlMappings;

  GeneralLedgerEntry? _glFor(CashflowManagerRow row) {
    final glId = _codeToGl[row.externalCode];
    if (glId == null) return null;
    final entries = context.read<ReferenceDataCache>().glEntries;
    for (final g in entries) {
      if (g.id == glId) return g;
    }
    return null;
  }

  List<CashflowManagerRow> get _importableRows =>
      _rows.where((r) => _glFor(r) != null).toList();

  List<CashflowManagerRow> get _skippedRows =>
      _rows.where((r) => _glFor(r) == null).toList();

  // ── Save ────────────────────────────────────────────────────────────────────

  String _receiptNumberFor(CashflowManagerRow row) {
    final ref = row.ref.trim();
    if (ref.isEmpty || ref.toUpperCase() == 'N/A') return 'Import';
    return ref;
  }

  // Includes amount because the catch-all import contact and the 'Import'
  // receipt fallback are shared by every unreferenced row — without amount,
  // two distinct split lines against the same GL code and date (a common
  // shape in this export) would collapse onto one fingerprint and the
  // second would be dropped as a false duplicate.
  String _fingerprint(String date, String contactId, String glId, String type,
          String receipt, int amountCents) =>
      '$date|$contactId|$glId|$type|$receipt|$amountCents';

  Future<void> _save() async {
    final toImport = _importableRows;
    if (toImport.isEmpty) return;

    setState(() {
      _saving = true;
      _saveStatus = 'Preparing…';
    });

    try {
      final client = context.read<ApiClient>();

      setState(() => _saveStatus = 'Finding import contact…');
      final contactId = await _findOrCreateImportContact(client);
      if (!mounted) return;

      setState(() => _saveStatus = 'Checking for duplicates…');
      final txRes = await client.get('/transactions');
      if (!mounted) return;
      final existing = <String>{};
      if (txRes.statusCode == 200) {
        final txns = (jsonDecode(txRes.body) as List)
            .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>));
        for (final t in txns) {
          existing.add(_fingerprint(t.transactionDate, t.contactId,
              t.generalLedgerId, t.transactionType, t.receiptNumber, t.amount));
        }
      }

      int saved = 0;
      int duplicates = 0;
      int failed = 0;

      for (int i = 0; i < toImport.length; i++) {
        if (!mounted) return;
        setState(() =>
            _saveStatus = 'Saving transactions… ${i + 1}/${toImport.length}');

        final row = toImport[i];
        final gl = _glFor(row)!;
        final type = gl.direction == GlDirection.moneyOut ? 'debit' : 'credit';
        final receipt = _receiptNumberFor(row);

        final fingerprint = _fingerprint(
            row.date, contactId, gl.id, type, receipt, row.amountCents);
        if (existing.contains(fingerprint)) {
          duplicates++;
          continue;
        }

        final body = jsonEncode({
          'contactId': contactId,
          'generalLedgerId': gl.id,
          'amount': row.amountCents,
          'gstAmount': row.gstCents,
          'transactionType': type,
          'receiptNumber': receipt,
          'description': row.description,
          'transactionDate': row.date,
        });

        final res = await client.post('/transactions', body);
        if (!mounted) return;
        if (res.statusCode == 201) {
          existing.add(fingerprint);
          saved++;
        } else {
          failed++;
        }
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveStatus = null;
      });

      final parts = <String>[
        'Imported $saved transaction${saved == 1 ? '' : 's'}',
        if (duplicates > 0) '$duplicates duplicate${duplicates == 1 ? '' : 's'} skipped',
        if (failed > 0) '$failed failed',
      ];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(parts.join(', ')),
        behavior: SnackBarBehavior.floating,
      ));

      if (mounted) Navigator.of(context).pop(saved > 0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveStatus = null;
        });
        _showSnackbar('Import failed: $e');
      }
    }
  }

  Future<String> _findOrCreateImportContact(ApiClient client) async {
    final cache = context.read<ReferenceDataCache>();
    for (final c in cache.contacts) {
      if (c.name.toLowerCase() == _importContactName.toLowerCase()) return c.id;
    }
    final res = await client.post(
      '/contacts',
      jsonEncode({
        'name': _importContactName,
        'contactType': 'company',
        'gstRegistered': false,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create import contact (${res.statusCode})');
    }
    final created =
        ContactEntry.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    if (mounted) cache.refreshContacts();
    return created.id;
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CashFlow Manager Transactions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : _fileName == null
                  ? _buildPickerPrompt()
                  : _buildImportView(),
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

  Widget _buildPickerPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Select a CashFlow Manager Transaction Listing CSV to begin.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Pick CSV File'),
          ),
        ],
      ),
    );
  }

  Widget _buildImportView() {
    if (_matching) {
      return const Center(child: CircularProgressIndicator());
    }

    final importable = _importableRows;
    final skipped = _skippedRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_fileName!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis),
              ),
              if (importable.isNotEmpty)
                Chip(
                  label: Text('${importable.length} to import'),
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade200),
                  labelStyle: TextStyle(color: Colors.green.shade700, fontSize: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              if (skipped.isNotEmpty) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text('${skipped.length} skipped'),
                  backgroundColor: Colors.orange.shade50,
                  side: BorderSide(color: Colors.orange.shade200),
                  labelStyle: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _saving ? null : _pickFile,
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('Change file'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildPreviewTable(),
          ),
        ),
        _buildSaveBar(importable),
      ],
    );
  }

  Widget _buildPreviewTable() {
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No transactions found in the file.',
            style: TextStyle(color: Colors.black54)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                SizedBox(width: 90, child: _headerLabel('Date')),
                SizedBox(width: 80, child: _headerLabel('Type')),
                Expanded(child: _headerLabel('Description')),
                SizedBox(width: 220, child: _headerLabel('GL Account')),
                SizedBox(width: 90, child: _headerLabel('Amount', align: TextAlign.right)),
                SizedBox(width: 90, child: _headerLabel('GST', align: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._rows.map(_buildPreviewRow),
        ],
      ),
    );
  }

  Widget _headerLabel(String text, {TextAlign align = TextAlign.left}) => Text(
        text,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      );

  Widget _buildPreviewRow(CashflowManagerRow row) {
    final gl = _glFor(row);
    final isMapped = gl != null;
    final isIncome = gl?.direction == GlDirection.moneyIn;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(_formatDate(row.date), style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 80,
                child: isMapped
                    ? Row(
                        children: [
                          Icon(
                            isIncome
                                ? Icons.arrow_circle_down_outlined
                                : Icons.arrow_circle_up_outlined,
                            size: 13,
                            color: isIncome
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(isIncome ? 'Income' : 'Expense',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isIncome
                                      ? Colors.green.shade700
                                      : Colors.red.shade700)),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: Text(row.description,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 220,
                child: isMapped
                    ? Text(gl.description,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis)
                    : Row(
                        children: [
                          Icon(Icons.warning_amber_outlined,
                              size: 14, color: Colors.orange.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${row.externalCode} — ${row.externalName}',
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(
                width: 90,
                child: Text(_formatCents(row.amountCents),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13, color: isMapped ? Colors.black87 : Colors.black38)),
              ),
              SizedBox(
                width: 90,
                child: Text(_formatCents(row.gstCents),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13, color: isMapped ? Colors.black87 : Colors.black38)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSaveBar(List<CashflowManagerRow> importable) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (_saving) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(_saveStatus ?? 'Saving…', style: Theme.of(context).textTheme.bodyMedium),
          ] else ...[
            Text(
              importable.isEmpty
                  ? 'No transactions ready — resolve GL codes above.'
                  : '${importable.length} transaction${importable.length == 1 ? '' : 's'} ready to import',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: (_saving || importable.isEmpty) ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(importable.isEmpty ? 'Import' : 'Import ${importable.length}'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _formatCents(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

// ── GL mapping dialog ──────────────────────────────────────────────────────────

/// Prompts once per unresolved GL code, pre-selecting the best fuzzy match
/// where one exists. Returns a map of code → chosen generalLedgerId (null
/// entries mean "skip this code"), or null if cancelled.
class _GlMappingDialog extends StatefulWidget {
  final List<_UnresolvedCode> codes;
  final List<GeneralLedgerEntry> glEntries;

  const _GlMappingDialog({required this.codes, required this.glEntries});

  @override
  State<_GlMappingDialog> createState() => _GlMappingDialogState();
}

class _GlMappingDialogState extends State<_GlMappingDialog> {
  @override
  Widget build(BuildContext context) {
    // Unsorted — buildGlPath resolves parents via an id map, not list order,
    // so this only needs to be the full account list. Per-row dropdowns sort
    // their own (direction-filtered) subset hierarchically; see _rowWidget.
    final allEntries = widget.glEntries;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Match GL Codes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "These codes from the CashFlow Manager export couldn't be matched "
                'confidently to an account in this system. Choose an account for '
                'each — the choice is remembered for the rest of this session.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const Row(children: [
                SizedBox(width: 220, child: Text('CashFlow Manager Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 70, child: Text('Count',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 60, child: Text('Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 12),
                Expanded(child: Text('GL Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.codes.length,
                  itemBuilder: (ctx, i) => _rowWidget(widget.codes[i], allEntries),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final result = <String, String?>{
                        for (final c in widget.codes) c.code: c.selectedGlId,
                      };
                      Navigator.of(context).pop(result);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowWidget(_UnresolvedCode item, List<GeneralLedgerEntry> allEntries) {
    // Restricted to the export's guessed direction for this code — Money In
    // codes only offer Money In accounts and vice versa — then ordered so
    // children sit immediately under their parent, siblings sorted by
    // label. buildGlPath/depth still walk the full (unfiltered) list so
    // parent-chain display isn't cut short by the direction filter.
    final directionAccounts = sortGlHierarchically(
      allEntries.where((g) => g.direction == item.direction).toList(),
    );

    // Guards against DropdownButton's "value must match exactly one item"
    // assertion — selectedGlId is only ever set from directionAccounts (or
    // cleared on a direction flip), but this is cheap insurance against
    // that invariant ever slipping, mirroring GlAccountDropdown.
    final resolvedValue = item.selectedGlId != null &&
            directionAccounts.any((g) => g.id == item.selectedGlId)
        ? item.selectedGlId
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(item.sampleName,
                    style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('${item.occurrences}', style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(width: 60, child: _directionToggle(item)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: resolvedValue,
              isExpanded: true,
              hint: const Text('— skip —', style: TextStyle(fontSize: 13)),
              underline: Container(
                height: 1,
                color: resolvedValue == null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outline,
              ),
              // The closed field renders whatever items[] shows by default,
              // which would otherwise be the depth-indented short
              // description — override it with the full path so a picked
              // nested account doesn't look like a bare, mis-indented leaf
              // once the dropdown is closed.
              selectedItemBuilder: (ctx) => [
                const Text('— skip —', style: TextStyle(fontSize: 13)),
                ...directionAccounts.map((g) => Text(
                      buildGlPath(allEntries, g.id),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    )),
              ],
              items: [
                const DropdownMenuItem(value: null, child: Text('— skip —')),
                ...directionAccounts.map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Padding(
                        padding:
                            EdgeInsets.only(left: glDepth(allEntries, g.id) * 16.0),
                        child: Text(g.description,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => item.selectedGlId = v),
            ),
          ),
        ],
      ),
    );
  }

  /// Tappable Money In/Out indicator. Defaults to the export's own guess
  /// (see [CashflowManagerRow.guessedDirection]) but can be flipped when
  /// that guess is wrong — clearing any selection made under the old
  /// direction, since it no longer applies.
  Widget _directionToggle(_UnresolvedCode item) {
    final isIn = item.direction == GlDirection.moneyIn;
    return Tooltip(
      message: isIn
          ? 'Guessed: Money In — tap to switch to Money Out'
          : 'Guessed: Money Out — tap to switch to Money In',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => setState(() {
          item.direction = isIn ? GlDirection.moneyOut : GlDirection.moneyIn;
          item.selectedGlId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isIn ? Colors.green.shade50 : Colors.red.shade50,
            border: Border.all(color: isIn ? Colors.green.shade200 : Colors.red.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIn ? Icons.arrow_circle_down_outlined : Icons.arrow_circle_up_outlined,
                size: 14,
                color: isIn ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 2),
              Text(isIn ? 'In' : 'Out',
                  style: TextStyle(
                      fontSize: 11, color: isIn ? Colors.green.shade700 : Colors.red.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}
