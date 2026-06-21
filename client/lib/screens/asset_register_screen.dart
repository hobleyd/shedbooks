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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/asset_entry.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';
import '../utils/asset_xlsx_parser.dart';

// ── Row editing model ─────────────────────────────────────────────────────────

/// A row in the asset table — wraps an [AssetEntry] with editing controllers.
class _AssetRow {
  final String? id;
  final TextEditingController assetNoCtrl;
  final TextEditingController assetTypeCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController identificationCtrl;
  final TextEditingController serialNoCtrl;
  final TextEditingController manufactureYearCtrl;
  final TextEditingController valueCtrl;
  final FocusNode assetNoFocus;
  // true while assetNoCtrl holds an auto-generated value (cleared on manual edit).
  bool assetNoAutoSet = false;

  // Originals for dirty-check and reset.
  final String _origAssetNo;
  final String _origAssetType;
  final String _origDescription;
  final String _origBrand;
  final String _origIdentification;
  final String _origSerialNo;
  final String _origManufactureYear;
  final String _origValue;

  _AssetRow.blank()
      : id = null,
        assetNoCtrl = TextEditingController(),
        assetTypeCtrl = TextEditingController(),
        descriptionCtrl = TextEditingController(),
        brandCtrl = TextEditingController(),
        identificationCtrl = TextEditingController(),
        serialNoCtrl = TextEditingController(),
        manufactureYearCtrl = TextEditingController(),
        valueCtrl = TextEditingController(),
        assetNoFocus = FocusNode(),
        _origAssetNo = '',
        _origAssetType = '',
        _origDescription = '',
        _origBrand = '',
        _origIdentification = '',
        _origSerialNo = '',
        _origManufactureYear = '',
        _origValue = '';

  _AssetRow.fromEntry(AssetEntry e)
      : id = e.id,
        assetNoCtrl = TextEditingController(text: e.assetNo),
        assetTypeCtrl = TextEditingController(text: e.assetType),
        descriptionCtrl = TextEditingController(text: e.description ?? ''),
        brandCtrl = TextEditingController(text: e.brand ?? ''),
        identificationCtrl = TextEditingController(text: e.identification ?? ''),
        serialNoCtrl = TextEditingController(text: e.serialNo ?? ''),
        manufactureYearCtrl = TextEditingController(
            text: e.manufactureYear?.toString() ?? ''),
        valueCtrl = TextEditingController(
            text: e.estimatedMarketValueDollars?.toString() ?? ''),
        assetNoFocus = FocusNode(),
        _origAssetNo = e.assetNo,
        _origAssetType = e.assetType,
        _origDescription = e.description ?? '',
        _origBrand = e.brand ?? '',
        _origIdentification = e.identification ?? '',
        _origSerialNo = e.serialNo ?? '',
        _origManufactureYear = e.manufactureYear?.toString() ?? '',
        _origValue = e.estimatedMarketValueDollars?.toString() ?? '';

  bool get isDirty =>
      assetNoCtrl.text != _origAssetNo ||
      assetTypeCtrl.text != _origAssetType ||
      descriptionCtrl.text != _origDescription ||
      brandCtrl.text != _origBrand ||
      identificationCtrl.text != _origIdentification ||
      serialNoCtrl.text != _origSerialNo ||
      manufactureYearCtrl.text != _origManufactureYear ||
      valueCtrl.text != _origValue;

  void reset() {
    assetNoCtrl.text = _origAssetNo;
    assetTypeCtrl.text = _origAssetType;
    descriptionCtrl.text = _origDescription;
    brandCtrl.text = _origBrand;
    identificationCtrl.text = _origIdentification;
    serialNoCtrl.text = _origSerialNo;
    manufactureYearCtrl.text = _origManufactureYear;
    valueCtrl.text = _origValue;
  }

  Map<String, dynamic> toRequestJson() {
    final yearStr = manufactureYearCtrl.text.trim();
    final valStr = valueCtrl.text.trim();
    final dollars = int.tryParse(valStr.replaceAll(RegExp(r'[,\$]'), ''));
    return {
      'assetNo': assetNoCtrl.text.trim(),
      'assetType': assetTypeCtrl.text.trim(),
      'description': descriptionCtrl.text.trim().isEmpty
          ? null
          : descriptionCtrl.text.trim(),
      'brand': brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
      'identification': identificationCtrl.text.trim().isEmpty
          ? null
          : identificationCtrl.text.trim(),
      'serialNo':
          serialNoCtrl.text.trim().isEmpty ? null : serialNoCtrl.text.trim(),
      'manufactureYear': yearStr.isEmpty ? null : int.tryParse(yearStr),
      'estimatedMarketValueCents': dollars != null ? dollars * 100 : null,
    };
  }

  void dispose() {
    assetNoCtrl.dispose();
    assetTypeCtrl.dispose();
    descriptionCtrl.dispose();
    brandCtrl.dispose();
    identificationCtrl.dispose();
    serialNoCtrl.dispose();
    manufactureYearCtrl.dispose();
    valueCtrl.dispose();
    assetNoFocus.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Asset Register screen — lists, edits, adds, deletes, and imports assets.
class AssetRegisterScreen extends StatefulWidget {
  const AssetRegisterScreen({super.key});

  @override
  State<AssetRegisterScreen> createState() => _AssetRegisterScreenState();
}

class _AssetRegisterScreenState extends State<AssetRegisterScreen> {
  List<_AssetRow> _rows = [];
  _AssetRow? _pendingNewRow;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  int? _sortColumn;
  bool _sortAscending = true;
  Set<String>? _sectionFilter;

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
    _pendingNewRow?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<ApiClient>();
      final res = await client.get('/assets');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final entries =
            data.map((e) => AssetEntry.fromJson(e as Map<String, dynamic>)).toList();
        final newRows = entries.map(_AssetRow.fromEntry).toList();
        if (mounted) {
          setState(() {
            for (final r in _rows) {
              r.dispose();
            }
            _rows = newRows;
            _applySort();
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load assets (${res.statusCode})';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading assets: $e';
          _loading = false;
        });
      }
    }
  }

  String? _nextAssetNoForSection(String section) {
    final sectionRows = _rows.where((r) => r.assetTypeCtrl.text == section);
    final pattern = RegExp(r'^(.*?)(\d+)$');
    String? bestPrefix;
    int bestNum = -1;
    int bestPadLen = 1;
    for (final r in sectionRows) {
      final m = pattern.firstMatch(r.assetNoCtrl.text.trim());
      if (m == null) continue;
      final num = int.parse(m.group(2)!);
      if (num > bestNum) {
        bestNum = num;
        bestPrefix = m.group(1)!;
        bestPadLen = m.group(2)!.length;
      }
    }
    if (bestPrefix == null) return null;
    return '$bestPrefix${(bestNum + 1).toString().padLeft(bestPadLen, '0')}';
  }

  void _addRow() {
    final row = _AssetRow.blank();
    if (_sectionFilter?.length == 1) {
      final section = _sectionFilter!.first;
      row.assetTypeCtrl.text = section;
      final autoNo = _nextAssetNoForSection(section);
      if (autoNo != null) {
        row.assetNoCtrl.text = autoNo;
        row.assetNoAutoSet = true;
      }
    }
    setState(() => _pendingNewRow = row);
    _updateDirty();
  }

  void _cancelNew() {
    setState(() {
      _pendingNewRow?.dispose();
      _pendingNewRow = null;
    });
    _updateDirty();
  }

  Future<void> _saveNewAsset(_AssetRow row) async {
    if (row.assetNoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset number must not be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final res =
          await client.post('/assets', jsonEncode(row.toRequestJson()));
      if (res.statusCode == 201) {
        _pendingNewRow?.dispose();
        setState(() => _pendingNewRow = null);
        await _load();
        _updateDirty();
      } else {
        final msg =
            (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String? ??
                'Save failed';
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRow(_AssetRow row) async {
    if (row.assetNoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset number must not be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final body = jsonEncode(row.toRequestJson());
      final res = row.id == null
          ? await client.post('/assets', body)
          : await client.put('/assets/${row.id}', body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _load();
        _updateDirty();
      } else {
        final msg =
            (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String? ??
                'Save failed';
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRow(_AssetRow row) async {
    if (row.id == null) {
      setState(() {
        _rows.remove(row);
        row.dispose();
        _updateDirty();
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete asset'),
        content: Text(
            'Remove ${row.assetNoCtrl.text} — ${row.descriptionCtrl.text.isEmpty ? 'no description' : row.descriptionCtrl.text}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
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

    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final res = await client.delete('/assets/${row.id}');
      if (res.statusCode == 204) {
        await _load();
        _updateDirty();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed (${res.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── XLSX import ─────────────────────────────────────────────────────────────

  /// Imports assets from the Asset Register spreadsheet.
  ///
  /// Reads each sheet (skipping 'Revisions' and 'Summary'); uses the trimmed
  /// sheet name as the asset_type. Columns:
  ///   0: Asset No, 1: Section (ignored), 2: Description, 3: Brand,
  ///   4: Identification, 5: Serial No, 6: Date of Manufacture (year),
  ///   7: Estimated Market Value (dollars → stored as cents)
  Future<void> _importFromXlsx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file data')),
        );
      }
      return;
    }

    final List<Map<String, dynamic>> assets;
    try {
      assets = AssetXlsxParser.parseBytes(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing file: $e')),
        );
      }
      return;
    }

    if (assets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No asset rows found in file')),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import assets'),
        content: Text(
          'Import/update ${assets.length} asset(s) from the selected file?\n\n'
          'Existing records with the same Asset No will be updated.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final res = await client.post('/assets/import', jsonEncode(assets));
      if (res.statusCode == 201) {
        final imported = (jsonDecode(res.body) as List<dynamic>).length;
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported/updated $imported asset(s)')),
          );
        }
      } else {
        final msg =
            (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String? ??
                'Import failed';
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error importing: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  void _applySort() {
    if (_sortColumn == null) return;
    _rows.sort((a, b) {
      String valueOf(_AssetRow r) => switch (_sortColumn) {
            0 => r.assetNoCtrl.text,
            1 => r.assetTypeCtrl.text,
            2 => r.descriptionCtrl.text,
            3 => r.brandCtrl.text,
            4 => r.identificationCtrl.text,
            5 => r.serialNoCtrl.text,
            6 => r.manufactureYearCtrl.text,
            7 => r.valueCtrl.text,
            _ => '',
          };

      final av = valueOf(a).toLowerCase();
      final bv = valueOf(b).toLowerCase();
      if (av.isEmpty && bv.isEmpty) return 0;
      if (av.isEmpty) return 1;
      if (bv.isEmpty) return -1;
      final cmp = av.compareTo(bv);
      return _sortAscending ? cmp : -cmp;
    });
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

  void _updateDirty() {
    final hasDirty = _pendingNewRow != null || _rows.any((r) => r.isDirty);
    context.read<NavigationGuard>().setDirty(hasDirty);
  }

  List<String> get _allTypes {
    final types = _rows.map((r) => r.assetTypeCtrl.text).toSet().toList()
      ..sort();
    return types;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final canEdit = authState.canEdit;
    final allTypes = _allTypes;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            onImport: canEdit ? _importFromXlsx : null,
            onRefresh: _loading ? null : _load,
            allTypes: allTypes,
            sectionFilter: _sectionFilter,
            onSectionFilterChanged: (v) => setState(() => _sectionFilter = v),
          ),
          const Divider(height: 1),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : _AssetTable(
                      rows: _rows,
                      canEdit: canEdit,
                      onSave: _saveRow,
                      onDelete: _deleteRow,
                      onChanged: _updateDirty,
                      sortColumn: _sortColumn,
                      sortAscending: _sortAscending,
                      onSort: _onSort,
                      pendingRow: _pendingNewRow,
                      onAddNew: canEdit ? _addRow : null,
                      onSaveNew: _saveNewAsset,
                      onCancelNew: _cancelNew,
                      sectionFilter: _sectionFilter,
                      onNextAssetNo: _nextAssetNoForSection,
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Toolbar ────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback? onImport;
  final VoidCallback? onRefresh;
  final List<String> allTypes;
  final Set<String>? sectionFilter;
  final ValueChanged<Set<String>?> onSectionFilterChanged;

  const _Toolbar({
    this.onImport,
    this.onRefresh,
    required this.allTypes,
    required this.sectionFilter,
    required this.onSectionFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Asset Register', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 24),
          if (allTypes.isNotEmpty) ...[
            const Text('Section:'),
            const SizedBox(width: 8),
            _SectionFilterDropdown(
              allSections: allTypes,
              selected: sectionFilter,
              onChanged: onSectionFilterChanged,
            ),
          ],
          const Spacer(),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: onRefresh,
            ),
          if (onImport != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import XLSX'),
              onPressed: onImport,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section filter dropdown ────────────────────────────────────────────────────

class _SectionFilterDropdown extends StatefulWidget {
  final List<String> allSections;
  // null = all visible; {} = none visible; non-empty = only those visible.
  final Set<String>? selected;
  final ValueChanged<Set<String>?> onChanged;

  const _SectionFilterDropdown({
    required this.allSections,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_SectionFilterDropdown> createState() => _SectionFilterDropdownState();
}

class _SectionFilterDropdownState extends State<_SectionFilterDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  // null = all visible; {} = none visible; non-empty = only those visible.
  Set<String>? _local;

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  void _open() {
    if (_overlay != null) {
      _close();
      return;
    }
    _local = widget.selected != null ? Set.from(widget.selected!) : null;
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  Widget _buildOverlay() {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _close,
        ),
      ),
      CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    title: const Text('All Sections',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    value: _local == null,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (_) => _selectAll(),
                  ),
                  const Divider(height: 1),
                  ...widget.allSections.map((s) {
                    final checked = _local == null || _local!.contains(s);
                    return CheckboxListTile(
                      title: Text(s, style: const TextStyle(fontSize: 13)),
                      value: checked,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (_) => _toggle(s),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  void _selectAll() {
    // Toggle: null (all) ↔ {} (none).
    _local = _local == null ? {} : null;
    widget.onChanged(_local != null ? Set.from(_local!) : null);
    _overlay?.markNeedsBuild();
  }

  void _toggle(String section) {
    if (_local == null) {
      // Was "all shown" — uncheck one → show all except this one.
      _local = Set.from(widget.allSections)..remove(section);
    } else if (_local!.contains(section)) {
      _local = Set.from(_local!)..remove(section);
    } else {
      _local = Set.from(_local!)..add(section);
      if (_local!.length == widget.allSections.length) _local = null;
    }
    widget.onChanged(_local != null ? Set.from(_local!) : null);
    _overlay?.markNeedsBuild();
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final label = sel == null
        ? 'All sections'
        : sel.isEmpty
            ? 'No sections'
            : sel.length == 1
                ? sel.first
                : '${sel.length} sections';
    final colorScheme = Theme.of(context).colorScheme;
    final isFiltered = sel != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isFiltered ? colorScheme.primary : colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(4),
            color: isFiltered
                ? colorScheme.primaryContainer.withAlpha(80)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 4),
              Icon(
                _overlay != null ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Table ──────────────────────────────────────────────────────────────────────

const double _kAssetNoW = 90;
const double _kTypeW = 130;
const double _kDescW = 220;
const double _kBrandW = 100;
const double _kIdentW = 110;
const double _kSerialW = 110;
const double _kYearW = 60;
const double _kValueW = 110;
const double _kActionsW = 80;

const double _kTableMinWidth = _kAssetNoW +
    _kTypeW +
    _kDescW +
    _kBrandW +
    _kIdentW +
    _kSerialW +
    _kYearW +
    _kValueW +
    _kActionsW;

// Edit panel inner width constants (panel has 16px padding each side).
// Asset No is widened to _kTypeW so longer numbers aren't truncated.
// Description fills the rest of row 1.
const double _kEditPanelPadding = 32; // 16 × 2
const double _kEditAssetNoW = _kTypeW;
const double _kEditDescW =
    _kTableMinWidth - _kEditPanelPadding - _kEditAssetNoW - 8 - (_kTypeW + 8) - 8;

class _AssetTable extends StatefulWidget {
  final List<_AssetRow> rows;
  final bool canEdit;
  final Future<void> Function(_AssetRow) onSave;
  final Future<void> Function(_AssetRow) onDelete;
  final VoidCallback onChanged;
  final int? sortColumn;
  final bool sortAscending;
  final void Function(int col) onSort;
  final _AssetRow? pendingRow;
  final VoidCallback? onAddNew;
  final Future<void> Function(_AssetRow)? onSaveNew;
  final VoidCallback? onCancelNew;
  final Set<String>? sectionFilter;
  final String? Function(String section)? onNextAssetNo;

  const _AssetTable({
    required this.rows,
    required this.canEdit,
    required this.onSave,
    required this.onDelete,
    required this.onChanged,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    this.pendingRow,
    this.onAddNew,
    this.onSaveNew,
    this.onCancelNew,
    required this.sectionFilter,
    this.onNextAssetNo,
  });

  @override
  State<_AssetTable> createState() => _AssetTableState();
}

class _AssetTableState extends State<_AssetTable> {
  final Set<String> _editing = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AssetTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingRow == null && widget.pendingRow != null) {
      final row = widget.pendingRow!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        row.assetNoFocus.requestFocus();
      });
    }
  }

  void _onSectionChangedForPending(_AssetRow row) {
    final section = row.assetTypeCtrl.text.trim();
    if (section.isEmpty) return;
    if (row.assetNoCtrl.text.isNotEmpty && !row.assetNoAutoSet) return;
    final autoNo = widget.onNextAssetNo?.call(section);
    if (autoNo != null) {
      row.assetNoCtrl.text = autoNo;
      row.assetNoAutoSet = true;
      setState(() {});
      widget.onChanged();
    }
  }

  void _startEdit(String key) => setState(() => _editing.add(key));

  void _cancelEdit(_AssetRow row, String key) {
    row.reset();
    widget.onChanged();
    setState(() => _editing.remove(key));
  }

  Future<void> _saveEdit(_AssetRow row, String key) async {
    await widget.onSave(row);
    if (mounted) setState(() => _editing.remove(key));
  }

  // ── Cell helpers ────────────────────────────────────────────────────────────

  Widget _readCell(BuildContext context, String text, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text.isEmpty ? '—' : text,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _sortHeader(BuildContext context, String label, int col, double width) {
    final isActive = widget.sortColumn == col;
    return InkWell(
      onTap: () => widget.onSort(col),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
              if (isActive)
                Icon(
                  widget.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 12,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit panel ──────────────────────────────────────────────────────────────

  Widget _buildEditPanel(BuildContext context, _AssetRow row,
      {required String key, bool isPending = false}) {
    final baseDec = InputDecoration(
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
    );

    Widget tf(String label, TextEditingController ctrl,
        {FocusNode? focusNode,
        List<TextInputFormatter>? inputFormatters,
        TextInputType? keyboardType,
        VoidCallback? extraOnChanged}) =>
        TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: baseDec.copyWith(labelText: label),
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          onChanged: (_) {
            widget.onChanged();
            extraOnChanged?.call();
          },
        );

    return Container(
      constraints: const BoxConstraints(minWidth: _kTableMinWidth),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: _kEditAssetNoW,
              child: tf('Asset No', row.assetNoCtrl,
                  focusNode: row.assetNoFocus,
                  extraOnChanged: isPending
                      ? () {
                          row.assetNoAutoSet = false;
                        }
                      : null),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _kTypeW + 8,
              child: tf('Section', row.assetTypeCtrl,
                  extraOnChanged: isPending
                      ? () => _onSectionChangedForPending(row)
                      : null),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _kEditDescW,
              child: tf('Description', row.descriptionCtrl),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: _kBrandW + 8,
              child: tf('Brand', row.brandCtrl),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: tf('Identification', row.identificationCtrl),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: tf('Serial No', row.serialNoCtrl),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _kYearW + 8,
              child: tf('Year', row.manufactureYearCtrl,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.number),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _kValueW + 8,
              child: tf('Est. Value (\$)', row.valueCtrl,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.number),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (isPending) ...[
              FilledButton(
                onPressed: () => widget.onSaveNew?.call(row),
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onCancelNew,
                child: const Text('Cancel'),
              ),
            ] else ...[
              FilledButton(
                onPressed: () => _saveEdit(row, key),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _cancelEdit(row, key),
                child: const Text('Cancel'),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  Widget _buildAddLink(BuildContext context) {
    return InkWell(
      onTap: widget.onAddNew,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.add,
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Add asset',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = widget.sectionFilter == null
        ? widget.rows
        : widget.sectionFilter!.isEmpty
            ? const <_AssetRow>[]
            : widget.rows
                .where((r) => widget.sectionFilter!.contains(r.assetTypeCtrl.text))
                .toList();

    return SingleChildScrollView(
      controller: _scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minWidth: _kTableMinWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(children: [
                  _sortHeader(context, 'Asset No', 0, _kAssetNoW),
                  _sortHeader(context, 'Section', 1, _kTypeW),
                  _sortHeader(context, 'Description', 2, _kDescW),
                  _sortHeader(context, 'Brand', 3, _kBrandW),
                  _sortHeader(context, 'Identification', 4, _kIdentW),
                  _sortHeader(context, 'Serial No', 5, _kSerialW),
                  _sortHeader(context, 'Year', 6, _kYearW),
                  _sortHeader(context, 'Est. Value', 7, _kValueW),
                  SizedBox(width: _kActionsW),
                ]),
              ),
              const Divider(height: 1),
              // Data rows
              ...filteredRows.expand((row) {
                final key = row.id ?? 'new-${row.hashCode}';
                final isEditing = _editing.contains(key);
                return [
                  _buildDataRow(context, row, key, isEditing),
                  if (isEditing)
                    _buildEditPanel(context, row, key: key),
                  const Divider(height: 1),
                ];
              }),
              // Pending new row
              if (widget.pendingRow != null) ...[
                _buildEditPanel(context, widget.pendingRow!,
                    key: 'pending', isPending: true),
                const Divider(height: 1),
              ],
              // Add link
              if (widget.canEdit && widget.pendingRow == null)
                _buildAddLink(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, _AssetRow row, String key,
      bool isEditing) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDirty = row.isDirty;
    return Container(
      color: isDirty ? colorScheme.tertiaryContainer.withAlpha(60) : null,
      child: Row(children: [
        _readCell(context, row.assetNoCtrl.text, _kAssetNoW),
        _readCell(context, row.assetTypeCtrl.text, _kTypeW),
        _readCell(context, row.descriptionCtrl.text, _kDescW),
        _readCell(context, row.brandCtrl.text, _kBrandW),
        _readCell(context, row.identificationCtrl.text, _kIdentW),
        _readCell(context, row.serialNoCtrl.text, _kSerialW),
        _readCell(context, row.manufactureYearCtrl.text, _kYearW),
        _readCell(
            context,
            row.valueCtrl.text.isEmpty ? '' : '\$${row.valueCtrl.text}',
            _kValueW),
        SizedBox(
          width: _kActionsW,
          child: widget.canEdit
              ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    iconSize: 16,
                    tooltip: 'Edit',
                    onPressed: isEditing ? null : () => _startEdit(key),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 16,
                    tooltip: 'Delete',
                    color: colorScheme.error,
                    onPressed: () => widget.onDelete(row),
                  ),
                ])
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

}
