import 'dart:convert';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_entry.dart';
import '../models/general_ledger_entry.dart';
import '../models/transaction_entry.dart';
import '../services/api_client.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class _ColMap {
  /// Unique key across both sheets, e.g. 'income_D', 'expense_E'.
  final String key;
  final String letter;
  final String header;
  final GlDirection direction;
  String? glEntryId;
  final bool autoMatched;

  _ColMap({
    required this.key,
    required this.letter,
    required this.header,
    required this.direction,
    this.glEntryId,
    required this.autoMatched,
  });
}

class _ImportRow {
  final String date;
  final String contact;
  final String receipt;
  final String description;
  final String colKey;
  final int totalCents;
  final String transactionType; // 'credit' (income) or 'debit' (expense)

  const _ImportRow({
    required this.date,
    required this.contact,
    required this.receipt,
    required this.description,
    required this.colKey,
    required this.totalCents,
    required this.transactionType,
  });
}

class _FailedImport {
  final String date;
  final String contact;
  final String glDescription;
  final int totalCents;
  final String reason;

  const _FailedImport({
    required this.date,
    required this.contact,
    required this.glDescription,
    required this.totalCents,
    required this.reason,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-screen import flow pushed modally over the Transactions screen.
///
/// Pops with [true] when at least one transaction has been saved so the
/// parent can refresh.
class ImportTransactionsScreen extends StatefulWidget {
  const ImportTransactionsScreen({super.key});

  @override
  State<ImportTransactionsScreen> createState() =>
      _ImportTransactionsScreenState();
}

class _ImportTransactionsScreenState extends State<ImportTransactionsScreen> {
  bool _loading = true;
  String? _loadError;
  List<GeneralLedgerEntry> _glEntries = [];
  List<ContactEntry> _contacts = [];

  String? _fileName;
  List<_ColMap> _columnMappings = [];
  List<_ImportRow> _parsedRows = [];

  bool _saving = false;
  String? _saveStatus;
  int? _sortColumn;
  bool _sortAscending = true;

  final _incomeScrollController = ScrollController();
  final _expenseScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  @override
  void dispose() {
    _incomeScrollController.dispose();
    _expenseScrollController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadReferenceData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/general-ledger'),
        client.get('/contacts'),
      ]);
      if (!mounted) return;
      if (results.any((r) => r.statusCode != 200)) {
        setState(() {
          _loadError = 'Failed to load reference data';
          _loading = false;
        });
        return;
      }
      final glEntries = (jsonDecode(results[0].body) as List)
          .map((e) => GeneralLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.description.compareTo(b.description));
      final contacts = (jsonDecode(results[1].body) as List)
          .map((e) => ContactEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _glEntries = glEntries;
        _contacts = contacts;
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

  // ── File parsing ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    _parseFile(bytes, file.name);
  }

  void _parseFile(List<int> bytes, String fileName) {
    try {
      final excel = Excel.decodeBytes(bytes);

      Sheet? _findSheet(String keyword) {
        final name = excel.tables.keys
            .where((n) => n.toLowerCase().contains(keyword))
            .firstOrNull;
        return name != null ? excel.tables[name] : null;
      }

      final incomeSheet = _findSheet('income');
      final expenseSheet = _findSheet('expense');

      if (incomeSheet == null && expenseSheet == null) {
        _showSnackbar('No Income or Expense sheet found in the selected file.');
        return;
      }

      final colMaps = <_ColMap>[];
      final importRows = <_ImportRow>[];

      if (incomeSheet != null) {
        final (cols, rows) = _parseSheet(
            incomeSheet, 'income', GlDirection.moneyIn, 'credit');
        colMaps.addAll(cols);
        importRows.addAll(rows);
      }
      if (expenseSheet != null) {
        final (cols, rows) = _parseSheet(
            expenseSheet, 'expense', GlDirection.moneyOut, 'debit');
        colMaps.addAll(cols);
        importRows.addAll(rows);
      }

      setState(() {
        _fileName = fileName;
        _columnMappings = colMaps;
        _parsedRows = importRows;
        _applySort();
      });
    } catch (e) {
      _showSnackbar('Failed to parse file: $e');
    }
  }

  (List<_ColMap>, List<_ImportRow>) _parseSheet(
    Sheet sheet,
    String sheetPrefix,
    GlDirection direction,
    String transactionType,
  ) {
    if (sheet.rows.isEmpty) return ([], []);

    final rows = sheet.rows;
    final headerRow = rows[0];

    String colLetter(int i) {
      if (i < 26) return String.fromCharCode('A'.codeUnitAt(0) + i);
      return String.fromCharCode('A'.codeUnitAt(0) + i ~/ 26 - 1) +
          String.fromCharCode('A'.codeUnitAt(0) + i % 26);
    }

    // Find optional description column (header == "Description", case-insensitive).
    int? descColIdx;
    for (int i = 0; i < headerRow.length; i++) {
      final h = _cellString(headerRow[i])?.trim().toLowerCase() ?? '';
      if (h == 'description') {
        descColIdx = i;
        break;
      }
    }

    final colMaps = <_ColMap>[];
    for (int i = 3; i < headerRow.length; i++) {
      if (i == descColIdx) continue;
      final header = _cellString(headerRow[i])?.trim() ?? '';
      if (header.toUpperCase() == 'TOTAL') break;
      if (header.isEmpty) continue;
      final letter = colLetter(i);
      final matched = _matchGl(header, direction);
      colMaps.add(_ColMap(
        key: '${sheetPrefix}_$letter',
        letter: letter,
        header: header,
        direction: direction,
        glEntryId: matched,
        autoMatched: matched != null,
      ));
    }

    final importRows = <_ImportRow>[];
    for (int ri = 1; ri < rows.length; ri++) {
      final row = rows[ri];
      final dateIso = _cellDateIso(row.isNotEmpty ? row[0] : null);
      if (dateIso == null) continue;

      final contact =
          _cellString(row.length > 1 ? row[1] : null)?.trim() ?? '';
      final receipt =
          _cellString(row.length > 2 ? row[2] : null)?.trim() ?? '';
      if (contact.isEmpty) continue;

      final description = descColIdx != null && descColIdx < row.length
          ? _cellString(row[descColIdx])?.trim() ?? ''
          : '';

      for (final col in colMaps) {
        final colIdx = col.letter.length == 1
            ? col.letter.codeUnitAt(0) - 'A'.codeUnitAt(0)
            : (col.letter.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1) * 26 +
                col.letter.codeUnitAt(1) - 'A'.codeUnitAt(0);

        if (colIdx >= row.length) continue;
        final amount = _cellNum(row[colIdx]);
        if (amount == null || amount <= 0) continue;

        importRows.add(_ImportRow(
          date: dateIso,
          contact: contact,
          receipt: receipt,
          description: description,
          colKey: col.key,
          totalCents: (amount * 100).round(),
          transactionType: transactionType,
        ));
      }
    }

    return (colMaps, importRows);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _applySort() {
    if (_sortColumn == null) return;
    _parsedRows.sort((a, b) {
      final int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.date.compareTo(b.date);
        case 1:
          cmp = a.contact.toLowerCase().compareTo(b.contact.toLowerCase());
        case 2:
          cmp = a.receipt.toLowerCase().compareTo(b.receipt.toLowerCase());
        case 3:
          cmp = a.transactionType.compareTo(b.transactionType);
        case 4:
          String glDesc(String colKey) {
            final glId = _mapForKey(colKey)?.glEntryId;
            if (glId == null) return '';
            return _glEntries
                .where((g) => g.id == glId)
                .map((g) => g.description)
                .firstOrNull ?? '';
          }
          cmp = glDesc(a.colKey).toLowerCase().compareTo(
              glDesc(b.colKey).toLowerCase());
        case 5:
          cmp = a.totalCents.compareTo(b.totalCents);
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

  String? _matchGl(String header, GlDirection direction) {
    final h = header.toLowerCase().trim();
    final entries =
        _glEntries.where((g) => g.direction == direction).toList();
    for (final g in entries) {
      if (g.description.toLowerCase().trim() == h) return g.id;
    }
    for (final g in entries) {
      final d = g.description.toLowerCase().trim();
      if (d.contains(h) || h.contains(d)) return g.id;
    }
    for (final g in entries) {
      if (g.label.toLowerCase().trim() == h) return g.id;
    }
    return null;
  }

  String? _cellString(Data? cell) {
    if (cell == null) return null;
    return switch (cell.value) {
      TextCellValue(:final value) =>
        value.toString().isEmpty ? null : value.toString(),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) => '$value',
      _ => null,
    };
  }

  double? _cellNum(Data? cell) {
    if (cell == null) return null;
    return switch (cell.value) {
      IntCellValue(:final value) => value.toDouble(),
      DoubleCellValue(:final value) => value,
      TextCellValue(:final value) =>
        double.tryParse(value.toString().trim()),
      _ => null,
    };
  }

  String? _cellDateIso(Data? cell) {
    if (cell == null) return null;
    return switch (cell.value) {
      DateCellValue(:final year, :final month, :final day) =>
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      DateTimeCellValue(:final year, :final month, :final day) =>
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      IntCellValue(:final value) when value > 0 => _serialToIso(value),
      DoubleCellValue(:final value) when value > 0 =>
        _serialToIso(value.round()),
      _ => null,
    };
  }

  String _serialToIso(int serial) {
    final d = DateTime(1899, 12, 30).add(Duration(days: serial));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  _ColMap? _mapForKey(String key) =>
      _columnMappings.where((m) => m.key == key).firstOrNull;

  List<_ImportRow> get _importableRows => _parsedRows
      .where((r) => _mapForKey(r.colKey)?.glEntryId != null)
      .toList();

  List<_ImportRow> get _skippedRows => _parsedRows
      .where((r) => _mapForKey(r.colKey)?.glEntryId == null)
      .toList();

  String _formatCents(int cents) {
    final d = cents / 100;
    return '\$${d.toStringAsFixed(2)}';
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Builds a deduplication fingerprint for an existing transaction.
  /// Uses receipt number (an exact stored string) rather than a computed
  /// amount to avoid any integer arithmetic discrepancy between the DB
  /// and the client-side calculation.
  String _existingFingerprint(TransactionEntry t) =>
      '${t.transactionDate}|${t.contactId}|${t.generalLedgerId}|${t.transactionType}|${t.receiptNumber}';

  /// Builds a deduplication fingerprint for a row about to be imported.
  /// Must produce the same string as [_existingFingerprint] for the same row.
  String _importFingerprint(
          String date, String contactId, String glId, String type, String receipt) =>
      '$date|$contactId|$glId|$type|$receipt';

  Future<void> _save() async {
    final toImport = _importableRows;
    if (toImport.isEmpty) return;

    setState(() {
      _saving = true;
      _saveStatus = 'Preparing…';
    });

    try {
      final client = context.read<ApiClient>();

      // Fetch contacts and existing transactions in parallel.
      setState(() => _saveStatus = 'Checking for duplicates…');
      final results = await Future.wait([
        client.get('/contacts'),
        client.get('/transactions'),
      ]);
      if (!mounted) return;

      List<ContactEntry> contacts = _contacts;
      if (results[0].statusCode == 200) {
        contacts = (jsonDecode(results[0].body) as List)
            .map((e) => ContactEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Build fingerprint set from all existing transactions.
      final existing = <String>{};
      if (results[1].statusCode == 200) {
        final txns = (jsonDecode(results[1].body) as List)
            .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>));
        for (final t in txns) {
          existing.add(_existingFingerprint(t));
        }
      }

      final contactMap = <String, String>{};
      for (final c in contacts) {
        contactMap[c.name.toLowerCase().trim()] = c.id;
      }

      final uniqueNewNames = toImport
          .map((r) => r.contact.trim())
          .toSet()
          .where((n) => !contactMap.containsKey(n.toLowerCase()))
          .toList();

      for (int i = 0; i < uniqueNewNames.length; i++) {
        if (!mounted) return;
        setState(() =>
            _saveStatus = 'Creating contacts… ${i + 1}/${uniqueNewNames.length}');
        final name = uniqueNewNames[i];
        final res = await client.post(
          '/contacts',
          jsonEncode({
            'name': name,
            'contactType': 'person',
            'gstRegistered': false,
          }),
        );
        if (!mounted) return;
        if (res.statusCode == 201) {
          final created = ContactEntry.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
          contactMap[name.toLowerCase()] = created.id;
        } else {
          throw Exception(
              'Failed to create contact "$name" (${res.statusCode})');
        }
      }

      int saved = 0;
      int duplicates = 0;
      final failures = <_FailedImport>[];

      for (int i = 0; i < toImport.length; i++) {
        if (!mounted) return;
        setState(() =>
            _saveStatus = 'Saving transactions… ${i + 1}/${toImport.length}');

        final row = toImport[i];
        final contactId = contactMap[row.contact.toLowerCase().trim()];
        if (contactId == null) continue;

        final glEntry = _glEntries
            .firstWhere((g) => g.id == _mapForKey(row.colKey)!.glEntryId);
        final gstCents =
            glEntry.gstApplicable ? (row.totalCents / 11).round() : 0;
        final amountCents = row.totalCents - gstCents;
        final receiptNumber = row.receipt.isEmpty ? 'Import' : row.receipt;

        final fingerprint = _importFingerprint(
            row.date, contactId, glEntry.id, row.transactionType, receiptNumber);
        if (existing.contains(fingerprint)) {
          duplicates++;
          continue;
        }

        final body = jsonEncode({
          'contactId': contactId,
          'generalLedgerId': glEntry.id,
          'amount': amountCents,
          'gstAmount': gstCents,
          'transactionType': row.transactionType,
          'receiptNumber': receiptNumber,
          'description': row.description,
          'transactionDate': row.date,
        });

        final res = await client.post('/transactions', body);
        if (!mounted) return;
        if (res.statusCode != 201) {
          String reason = 'Server error (${res.statusCode})';
          try {
            final json = jsonDecode(res.body) as Map<String, dynamic>;
            reason = json['error'] as String? ?? reason;
          } catch (_) {}
          failures.add(_FailedImport(
            date: row.date,
            contact: row.contact,
            glDescription: glEntry.description,
            totalCents: row.totalCents,
            reason: reason,
          ));
          continue;
        }

        // Add to the set so duplicate rows within the same file are also caught.
        existing.add(fingerprint);
        saved++;
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveStatus = null;
      });

      if (failures.isNotEmpty) {
        await _showFailuresDialog(failures, saved, duplicates);
      } else {
        final message = saved == 0 && duplicates > 0
            ? 'All $duplicates transaction${duplicates == 1 ? '' : 's'} already imported — nothing new to save.'
            : 'Imported $saved transaction${saved == 1 ? '' : 's'}'
                '${duplicates > 0 ? ' ($duplicates duplicate${duplicates == 1 ? '' : 's'} skipped)' : ''}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ));
      }

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

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showFailuresDialog(
      List<_FailedImport> failures, int saved, int duplicates) async {
    if (!mounted) return;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(ctx).colorScheme.error, size: 20),
            const SizedBox(width: 8),
            const Text('Some rows failed to import'),
          ],
        ),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (saved > 0 || duplicates > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${saved > 0 ? '$saved transaction${saved == 1 ? '' : 's'} imported successfully' : 'No transactions imported'}'
                    '${duplicates > 0 ? ', $duplicates duplicate${duplicates == 1 ? '' : 's'} skipped' : ''}.'
                    ' The following ${failures.length} row${failures.length == 1 ? '' : 's'} could not be saved:',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 80, child: Text('Date', style: labelStyle)),
                            SizedBox(width: 140, child: Text('Contact', style: labelStyle)),
                            SizedBox(width: 140, child: Text('GL Account', style: labelStyle)),
                            SizedBox(width: 70, child: Text('Amount', style: labelStyle, textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...failures.map((f) => Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(_formatDate(f.date),
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: Text(f.contact,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: Text(f.glDescription,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(_formatCents(f.totalCents),
                                          style: const TextStyle(fontSize: 12),
                                          textAlign: TextAlign.right),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 12,
                                        color: Theme.of(ctx).colorScheme.error),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        f.reason,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(ctx).colorScheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Transactions'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildError()
              : _fileName == null
                  ? _buildEmptyState()
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
          FilledButton(
              onPressed: _loadReferenceData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.upload_file_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Select an Excel (.xlsx) cash book to import',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            'The Income and Expense sheets will be read. '
            'Columns D onwards are treated as GL accounts.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black38),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  Widget _buildImportView() {
    final importable = _importableRows;
    final skipped = _skippedRows;
    final unmappedCols =
        _columnMappings.where((m) => m.glEntryId == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── File banner ──────────────────────────────────────────────────────
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Column mapping ───────────────────────────────────────────
                Text('Column Mapping',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Each spreadsheet column must be linked to a General Ledger account. '
                  'Auto-matched columns are shown with a green indicator.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildColumnMappingSection(GlDirection.moneyIn),
                _buildColumnMappingSection(GlDirection.moneyOut),
                const SizedBox(height: 24),

                // ── Preview table ────────────────────────────────────────────
                Row(
                  children: [
                    Text('Preview',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 12),
                    if (importable.isNotEmpty)
                      Chip(
                        label: Text('${importable.length} to import'),
                        backgroundColor: Colors.green.shade50,
                        side: BorderSide(color: Colors.green.shade200),
                        labelStyle: TextStyle(
                            color: Colors.green.shade700, fontSize: 12),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (skipped.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${skipped.length} skipped'),
                        backgroundColor: Colors.orange.shade50,
                        side: BorderSide(color: Colors.orange.shade200),
                        labelStyle: TextStyle(
                            color: Colors.orange.shade700, fontSize: 12),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                if (skipped.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$unmappedCols column${unmappedCols == 1 ? '' : 's'} '
                    'without a GL mapping — those rows will be skipped.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ],
                const SizedBox(height: 12),
                _buildPreviewTable(),
              ],
            ),
          ),
        ),

        // ── Save bar ─────────────────────────────────────────────────────────
        _buildSaveBar(importable),
      ],
    );
  }

  Widget _buildColumnMappingSection(GlDirection direction) {
    final cols =
        _columnMappings.where((m) => m.direction == direction).toList();
    if (cols.isEmpty) return const SizedBox.shrink();

    final isIncome = direction == GlDirection.moneyIn;
    final label = isIncome ? 'Income' : 'Expenses';
    final controller =
        isIncome ? _incomeScrollController : _expenseScrollController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isIncome
                  ? Icons.arrow_circle_down_outlined
                  : Icons.arrow_circle_up_outlined,
              size: 14,
              color: isIncome ? Colors.green.shade600 : Colors.red.shade600,
            ),
            const SizedBox(width: 4),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                        color: isIncome
                            ? Colors.green.shade700
                            : Colors.red.shade700)),
          ],
        ),
        const SizedBox(height: 6),
        Scrollbar(
          controller: controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cols.map((col) => _buildColCard(col)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildColCard(_ColMap col) {
    final isMatched = col.glEntryId != null;
    final glEntries =
        _glEntries.where((g) => g.direction == col.direction).toList();

    return Card(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isMatched
              ? (col.autoMatched
                  ? Colors.green.shade200
                  : Colors.blue.shade200)
              : Colors.orange.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 210,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Col ${col.letter}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.black45)),
                  const Spacer(),
                  Icon(
                    isMatched
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    size: 14,
                    color: isMatched
                        ? (col.autoMatched
                            ? Colors.green.shade600
                            : Colors.blue.shade600)
                        : Colors.orange.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                col.header,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: DropdownButton<String>(
                  value: col.glEntryId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  isDense: true,
                  hint: const Text('Select GL…',
                      style: TextStyle(fontSize: 12)),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child:
                            Text('(Skip)', style: TextStyle(fontSize: 12))),
                    ...glEntries.map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.description,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => col.glEntryId = v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_parsedRows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No transactions found in the file.',
            style: TextStyle(color: Colors.black54)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                SizedBox(width: 96, child: _colHeader('Date', 0)),
                SizedBox(width: 180, child: _colHeader('Contact', 1)),
                SizedBox(width: 110, child: _colHeader('Receipt No.', 2)),
                SizedBox(width: 80, child: _colHeader('Type', 3)),
                Expanded(child: _colHeader('GL Account', 4)),
                SizedBox(
                    width: 100,
                    child: _colHeader('Amount', 5,
                        align: MainAxisAlignment.end)),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._parsedRows.map((row) => _buildPreviewRow(row)),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(_ImportRow row) {
    final col = _mapForKey(row.colKey);
    final glId = col?.glEntryId;
    final glEntry = glId != null
        ? _glEntries.firstWhere((g) => g.id == glId,
            orElse: () => GeneralLedgerEntry(
                  id: '',
                  label: '?',
                  description: '?',
                  gstApplicable: false,
                  direction: GlDirection.moneyIn,
                ))
        : null;
    final isMapped = glEntry != null;
    final isIncome = row.transactionType == 'credit';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(_formatDate(row.date),
                    style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.contact,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    if (row.description.isNotEmpty)
                      Text(row.description,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(row.receipt,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 80,
                child: Row(
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
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                          fontSize: 12,
                          color: isIncome
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isMapped
                    ? Text(glEntry.description,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis)
                    : Row(
                        children: [
                          Icon(Icons.warning_amber_outlined,
                              size: 14, color: Colors.orange.shade600),
                          const SizedBox(width: 4),
                          Text(
                            col?.header ?? row.colKey,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  _formatCents(row.totalCents),
                  style: TextStyle(
                    fontSize: 13,
                    color: isMapped ? Colors.black87 : Colors.black38,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSaveBar(List<_ImportRow> importable) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor)),
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
            Text(_saveStatus ?? 'Saving…',
                style: Theme.of(context).textTheme.bodyMedium),
          ] else ...[
            Text(
              importable.isEmpty
                  ? 'No transactions ready — assign GL accounts above.'
                  : '${importable.length} transaction${importable.length == 1 ? '' : 's'} ready to import',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: (_saving || importable.isEmpty) ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(
                importable.isEmpty ? 'Import' : 'Import ${importable.length}'),
          ),
        ],
      ),
    );
  }

  // ── Formatting ───────────────────────────────────────────────────────────────

  String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
