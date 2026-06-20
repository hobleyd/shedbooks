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

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/member_entry.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';

/// A row in the membership table — wraps a [MemberEntry] with editing state.
class _MemberRow {
  final String? id;
  final TextEditingController lastNameCtrl;
  final TextEditingController firstNameCtrl;
  final TextEditingController dateJoinedCtrl;
  final TextEditingController statusCtrl;
  final TextEditingController streetCtrl;
  final TextEditingController poBoxCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController dobCtrl;
  final TextEditingController emergencyCtrl;
  final TextEditingController woodworkingCtrl;
  final TextEditingController metalworkingCtrl;
  final TextEditingController gymWaiverCtrl;
  final FocusNode firstNameFocus;
  final FocusNode lastNameFocus;

  // Originals for dirty-check
  final String _origLastName;
  final String _origFirstName;
  final String _origDateJoined;
  final String _origStatus;
  final String _origStreet;
  final String _origPoBox;
  final String _origEmail;
  final String _origPhone;
  final String _origDob;
  final String _origEmergency;
  final String _origWoodworking;
  final String _origMetalworking;
  final String _origGymWaiver;

  _MemberRow.blank()
      : id = null,
        lastNameCtrl = TextEditingController(),
        firstNameCtrl = TextEditingController(),
        dateJoinedCtrl = TextEditingController(),
        statusCtrl = TextEditingController(),
        streetCtrl = TextEditingController(),
        poBoxCtrl = TextEditingController(),
        emailCtrl = TextEditingController(),
        phoneCtrl = TextEditingController(),
        dobCtrl = TextEditingController(),
        emergencyCtrl = TextEditingController(),
        woodworkingCtrl = TextEditingController(),
        metalworkingCtrl = TextEditingController(),
        gymWaiverCtrl = TextEditingController(),
        firstNameFocus = FocusNode(),
        lastNameFocus = FocusNode(),
        _origLastName = '',
        _origFirstName = '',
        _origDateJoined = '',
        _origStatus = '',
        _origStreet = '',
        _origPoBox = '',
        _origEmail = '',
        _origPhone = '',
        _origDob = '',
        _origEmergency = '',
        _origWoodworking = '',
        _origMetalworking = '',
        _origGymWaiver = '';

  _MemberRow.fromEntry(MemberEntry e)
      : id = e.id,
        lastNameCtrl = TextEditingController(text: e.lastName),
        firstNameCtrl = TextEditingController(text: e.firstName),
        dateJoinedCtrl = TextEditingController(text: e.dateJoined ?? ''),
        statusCtrl =
            TextEditingController(text: e.membershipStatus ?? ''),
        streetCtrl = TextEditingController(text: e.streetAddress ?? ''),
        poBoxCtrl = TextEditingController(text: e.poBox ?? ''),
        emailCtrl = TextEditingController(text: e.email ?? ''),
        phoneCtrl = TextEditingController(text: e.phone ?? ''),
        dobCtrl = TextEditingController(text: e.dateOfBirth ?? ''),
        emergencyCtrl =
            TextEditingController(text: e.emergencyContact ?? ''),
        woodworkingCtrl =
            TextEditingController(text: e.woodworkingInduction ?? ''),
        metalworkingCtrl =
            TextEditingController(text: e.metalworkingInduction ?? ''),
        gymWaiverCtrl = TextEditingController(text: e.gymWaiver ?? ''),
        firstNameFocus = FocusNode(),
        lastNameFocus = FocusNode(),
        _origLastName = e.lastName,
        _origFirstName = e.firstName,
        _origDateJoined = e.dateJoined ?? '',
        _origStatus = e.membershipStatus ?? '',
        _origStreet = e.streetAddress ?? '',
        _origPoBox = e.poBox ?? '',
        _origEmail = e.email ?? '',
        _origPhone = e.phone ?? '',
        _origDob = e.dateOfBirth ?? '',
        _origEmergency = e.emergencyContact ?? '',
        _origWoodworking = e.woodworkingInduction ?? '',
        _origMetalworking = e.metalworkingInduction ?? '',
        _origGymWaiver = e.gymWaiver ?? '';

  bool get isDirty =>
      lastNameCtrl.text != _origLastName ||
      firstNameCtrl.text != _origFirstName ||
      dateJoinedCtrl.text != _origDateJoined ||
      statusCtrl.text != _origStatus ||
      streetCtrl.text != _origStreet ||
      poBoxCtrl.text != _origPoBox ||
      emailCtrl.text != _origEmail ||
      phoneCtrl.text != _origPhone ||
      dobCtrl.text != _origDob ||
      emergencyCtrl.text != _origEmergency ||
      woodworkingCtrl.text != _origWoodworking ||
      metalworkingCtrl.text != _origMetalworking ||
      gymWaiverCtrl.text != _origGymWaiver;

  Map<String, dynamic> toRequestJson() => {
        'lastName': lastNameCtrl.text.trim(),
        'firstName': firstNameCtrl.text.trim(),
        'dateJoined': dateJoinedCtrl.text.trim().isEmpty
            ? null
            : dateJoinedCtrl.text.trim(),
        'membershipStatus': statusCtrl.text.trim().isEmpty
            ? null
            : statusCtrl.text.trim(),
        'streetAddress':
            streetCtrl.text.trim().isEmpty ? null : streetCtrl.text.trim(),
        'poBox': poBoxCtrl.text.trim().isEmpty ? null : poBoxCtrl.text.trim(),
        'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'dateOfBirth':
            dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
        'emergencyContact': emergencyCtrl.text.trim().isEmpty
            ? null
            : emergencyCtrl.text.trim(),
        'woodworkingInduction': woodworkingCtrl.text.trim().isEmpty
            ? null
            : woodworkingCtrl.text.trim(),
        'metalworkingInduction': metalworkingCtrl.text.trim().isEmpty
            ? null
            : metalworkingCtrl.text.trim(),
        'gymWaiver':
            gymWaiverCtrl.text.trim().isEmpty ? null : gymWaiverCtrl.text.trim(),
      };

  void reset() {
    lastNameCtrl.text = _origLastName;
    firstNameCtrl.text = _origFirstName;
    dateJoinedCtrl.text = _origDateJoined;
    statusCtrl.text = _origStatus;
    streetCtrl.text = _origStreet;
    poBoxCtrl.text = _origPoBox;
    emailCtrl.text = _origEmail;
    phoneCtrl.text = _origPhone;
    dobCtrl.text = _origDob;
    emergencyCtrl.text = _origEmergency;
    woodworkingCtrl.text = _origWoodworking;
    metalworkingCtrl.text = _origMetalworking;
    gymWaiverCtrl.text = _origGymWaiver;
  }

  void dispose() {
    lastNameCtrl.dispose();
    firstNameCtrl.dispose();
    dateJoinedCtrl.dispose();
    statusCtrl.dispose();
    streetCtrl.dispose();
    poBoxCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    dobCtrl.dispose();
    emergencyCtrl.dispose();
    woodworkingCtrl.dispose();
    metalworkingCtrl.dispose();
    gymWaiverCtrl.dispose();
    firstNameFocus.dispose();
    lastNameFocus.dispose();
  }
}

/// Membership roster screen with inline table editing and XLSX import.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  List<_MemberRow> _rows = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;
  _MemberRow? _pendingNewRow;
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
      final res = await client.get('/members');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final entries =
            data.map((e) => MemberEntry.fromJson(e as Map<String, dynamic>)).toList();
        final newRows = entries.map(_MemberRow.fromEntry).toList();
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
        setState(() {
          _error = 'Failed to load members (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading members: $e';
          _loading = false;
        });
      }
    }
  }

  void _addRow() {
    setState(() => _pendingNewRow = _MemberRow.blank());
    _updateDirty();
  }

  void _cancelNew() {
    setState(() {
      _pendingNewRow?.dispose();
      _pendingNewRow = null;
    });
    _updateDirty();
  }

  Future<void> _saveNewMember(_MemberRow row) async {
    if (row.lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last name must not be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final res =
          await client.post('/members', jsonEncode(row.toRequestJson()));
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

  Future<void> _saveRow(_MemberRow row) async {
    if (row.lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last name must not be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final body = jsonEncode(row.toRequestJson());
      final res = row.id == null
          ? await client.post('/members', body)
          : await client.put('/members/${row.id}', body);
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

  Future<void> _deleteRow(_MemberRow row) async {
    if (row.id == null) {
      // Not yet persisted — just remove from UI.
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
        title: const Text('Delete member'),
        content: Text('Remove ${row.firstNameCtrl.text} ${row.lastNameCtrl.text}? This cannot be undone.'),
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
      final res = await client.delete('/members/${row.id}');
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

  /// Imports members from an XLSX file selected by the user.
  ///
  /// Reads the first sheet that contains a "Name" header column and maps all
  /// recognised columns to the [MemberEntry] fields.  The imported records are
  /// sent to `POST /members/import` in a single request.
  Future<void> _importFromXlsx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final excel = Excel.decodeBytes(bytes);
    Sheet? sheet;
    // Prefer "Membership List 2025" if present.
    sheet = excel.tables['Membership List 2025'] ??
        excel.tables.values.firstOrNull;
    if (sheet == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sheet found in workbook')),
        );
      }
      return;
    }

    // Find header row
    final rows = sheet.rows;
    if (rows.isEmpty) return;
    final headers = rows.first
        .map((c) => (c?.value?.toString() ?? '').toLowerCase().trim())
        .toList();

    int col(String name) => headers.indexOf(name);
    final nameCol = col('name');
    final dateJoinedCol = col('date joined');
    final statusCol = col('status');
    final streetCol = col('street address');
    final poBoxCol = col('po box');
    final emailCol = col('email');
    final phoneCol = col('phone');
    final dobCol = col('d.o.b');
    final emergencyCol = col('emergency contact');

    if (nameCol < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find "Name" column')),
        );
      }
      return;
    }

    String? _cell(List<Data?> row, int col) {
      if (col < 0 || col >= row.length) return null;
      final v = row[col]?.value;
      if (v == null) return null;
      final str = v.toString().trim();
      return str.isEmpty ? null : str;
    }

    String? _dateCell(List<Data?> row, int col) {
      if (col < 0 || col >= row.length) return null;
      final v = row[col]?.value;
      if (v == null) return null;
      if (v is DateCellValue) {
        final dt = v.asDateTimeLocal();
        return '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
      }
      // Try parse as string
      final str = v.toString().trim();
      try {
        final dt = DateTime.parse(str);
        return '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return null;
      }
    }

    String? _statusCell(List<Data?> row, int col) {
      if (col < 0 || col >= row.length) return null;
      final v = row[col]?.value;
      if (v == null) return null;
      // Year values come as IntCellValue or DoubleCellValue.
      if (v is IntCellValue) return v.value.toString();
      if (v is DoubleCellValue) return v.value.toInt().toString();
      final str = v.toString().trim();
      return str.isEmpty ? null : str;
    }

    final members = <Map<String, dynamic>>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = _cell(row, nameCol);
      if (name == null || name.isEmpty) continue;
      members.add({
        'name': name,
        'dateJoined': _dateCell(row, dateJoinedCol),
        'membershipStatus': _statusCell(row, statusCol),
        'streetAddress': _cell(row, streetCol),
        'poBox': _cell(row, poBoxCol),
        'email': _cell(row, emailCol),
        'phone': _cell(row, phoneCol),
        'dateOfBirth': _dateCell(row, dobCol),
        'emergencyContact': _cell(row, emergencyCol),
      });
    }

    if (members.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No member rows found in file')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import members'),
        content: Text(
          'Import ${members.length} member(s) from the selected file?\n\n'
          'This will add new records — existing records are not modified.',
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
      final res = await client.post('/members/import', jsonEncode(members));
      if (res.statusCode == 201) {
        final imported = (jsonDecode(res.body) as List<dynamic>).length;
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $imported member(s)')),
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
      String valueOf(_MemberRow r) {
        return switch (_sortColumn) {
          0 => r.firstNameCtrl.text,
          1 => r.lastNameCtrl.text,
          2 => r.dateJoinedCtrl.text,
          3 => r.statusCtrl.text,
          4 => r.streetCtrl.text,
          5 => r.poBoxCtrl.text,
          6 => r.emailCtrl.text,
          7 => r.phoneCtrl.text,
          8 => r.dobCtrl.text,
          9 => r.emergencyCtrl.text,
          10 => r.woodworkingCtrl.text,
          11 => r.metalworkingCtrl.text,
          12 => r.gymWaiverCtrl.text,
          _ => '',
        };
      }

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

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final canEdit = authState.canEdit;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            onImport: canEdit ? _importFromXlsx : null,
            onRefresh: _loading ? null : _load,
          ),
          const Divider(height: 1),
          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
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
                    ElevatedButton(
                        onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : _MemberTable(
                        rows: _rows,
                        canEdit: canEdit,
                        onSave: _saveRow,
                        onDelete: _deleteRow,
                        onChanged: _updateDirty,
                        sortColumn: _sortColumn,
                        sortAscending: _sortAscending,
                        onSort: _onSort,
                        pendingRow: _pendingNewRow,
                        onAddNew: _addRow,
                        onSaveNew: _saveNewMember,
                        onCancelNew: _cancelNew,
                      ),
            ),
        ],
      ),
    );
  }
}

// ── Toolbar ────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback? onImport;
  final VoidCallback? onRefresh;

  const _Toolbar({this.onImport, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Members',
              style: Theme.of(context).textTheme.titleLarge),
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

// ── Table ──────────────────────────────────────────────────────────────────

// Fixed widths for always-visible primary columns.
const double _kExpandW = 32;
const double _kFirstNameW = 120;
const double _kLastNameW = 130;
const double _kDateJoinedW = 100;
const double _kStatusW = 80;
const double _kPhoneW = 120;
const double _kWoodworkingW = 130;
const double _kMetalworkingW = 130;
const double _kGymWaiverW = 100;
const double _kActionsW = 80;

class _MemberTable extends StatefulWidget {
  final List<_MemberRow> rows;
  final bool canEdit;
  final Future<void> Function(_MemberRow) onSave;
  final Future<void> Function(_MemberRow) onDelete;
  final VoidCallback onChanged;
  final int? sortColumn;
  final bool sortAscending;
  final void Function(int col) onSort;
  final _MemberRow? pendingRow;
  final VoidCallback? onAddNew;
  final Future<void> Function(_MemberRow)? onSaveNew;
  final VoidCallback? onCancelNew;

  const _MemberTable({
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
  });

  @override
  State<_MemberTable> createState() => _MemberTableState();
}

class _MemberTableState extends State<_MemberTable> {
  final Set<String> _expanded = {};
  final Set<String> _editing = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MemberTable oldWidget) {
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
        row.firstNameFocus.requestFocus();
      });
    }
  }

  void _toggleExpand(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  void _startEdit(String key) {
    setState(() => _editing.add(key));
  }

  void _cancelEdit(_MemberRow row, String key) {
    row.reset();
    widget.onChanged();
    setState(() => _editing.remove(key));
  }

  Future<void> _saveEdit(_MemberRow row, String key) async {
    await widget.onSave(row);
    if (mounted) setState(() => _editing.remove(key));
  }

  // ── Shared cell helpers ────────────────────────────────────────────────────

  Widget _readCell(BuildContext context, TextEditingController ctrl, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          ctrl.text.isEmpty ? '—' : ctrl.text,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _subLabel(BuildContext context, String label, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Date cell helpers ──────────────────────────────────────────────────────

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final parts = iso.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return iso;
  }

  static String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime? initial;
    if (ctrl.text.isNotEmpty) {
      try {
        initial = DateTime.parse(ctrl.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2060),
    );
    if (picked != null && mounted) {
      ctrl.text = _isoDate(picked);
      widget.onChanged();
      setState(() {});
    }
  }

  void _clearDate(TextEditingController ctrl) {
    ctrl.text = '';
    widget.onChanged();
    setState(() {});
  }

  Widget _readDateCell(
      BuildContext context, TextEditingController ctrl, double width) {
    final formatted = _formatDate(ctrl.text);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          formatted.isEmpty ? '—' : formatted,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  // ── Edit panel ─────────────────────────────────────────────────────────────

  Widget _buildDateField(BuildContext context, String label,
      TextEditingController ctrl, InputDecoration baseDec) {
    final formatted = _formatDate(ctrl.text);
    final hasValue = ctrl.text.isNotEmpty;
    return GestureDetector(
      onTap: () => _pickDate(ctrl),
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: baseDec.copyWith(
          labelText: label,
          suffixIcon: hasValue
              ? GestureDetector(
                  onTap: () => _clearDate(ctrl),
                  child: const Icon(Icons.clear, size: 18),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          formatted,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildEditPanel(BuildContext context, _MemberRow row,
      {required String key, bool isPending = false}) {
    final baseDec = InputDecoration(
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
    );

    Widget tf(String label, TextEditingController ctrl,
        {FocusNode? focusNode}) =>
        TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: baseDec.copyWith(labelText: label),
          onChanged: (_) => widget.onChanged(),
        );

    Widget df(String label, TextEditingController ctrl) =>
        _buildDateField(context, label, ctrl, baseDec);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
                width: _kFirstNameW + 8,
                child: tf('First Name', row.firstNameCtrl,
                    focusNode: row.firstNameFocus)),
            const SizedBox(width: 8),
            SizedBox(
                width: _kLastNameW + 8,
                child: tf('Last Name', row.lastNameCtrl,
                    focusNode: row.lastNameFocus)),
            const SizedBox(width: 8),
            SizedBox(
                width: _kDateJoinedW + 16,
                child: df('Date Joined', row.dateJoinedCtrl)),
            const SizedBox(width: 8),
            SizedBox(width: _kStatusW + 8, child: tf('Status', row.statusCtrl)),
            const SizedBox(width: 8),
            SizedBox(width: _kPhoneW + 8, child: tf('Phone', row.phoneCtrl)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 200, child: tf('Street Address', row.streetCtrl)),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: tf('PO Box', row.poBoxCtrl)),
            const SizedBox(width: 8),
            SizedBox(width: 200, child: tf('Email', row.emailCtrl)),
            const SizedBox(width: 8),
            SizedBox(
                width: 120, child: df('Date of Birth', row.dobCtrl)),
            const SizedBox(width: 8),
            SizedBox(
                width: 180,
                child: tf('Emergency Contact', row.emergencyCtrl)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
                width: _kWoodworkingW + 16,
                child: df('Woodworking Induction', row.woodworkingCtrl)),
            const SizedBox(width: 8),
            SizedBox(
                width: _kMetalworkingW + 16,
                child: df('Metalworking Induction', row.metalworkingCtrl)),
            const SizedBox(width: 8),
            SizedBox(
                width: _kGymWaiverW + 16,
                child: df('Gym Waiver', row.gymWaiverCtrl)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: isPending
                    ? () => widget.onSaveNew?.call(row)
                    : () => _saveEdit(row, key),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: isPending
                    ? widget.onCancelNew
                    : () => _cancelEdit(row, key),
                child: const Text('Cancel'),
              ),
              if (!isPending) ...[
                const Spacer(),
                TextButton.icon(
                  icon: Icon(Icons.delete_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.error),
                  label: Text('Delete',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  onPressed: () => widget.onDelete(row),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _headerCell(
      BuildContext context, String label, int sortIndex, double width) {
    final isActive = widget.sortColumn == sortIndex;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => widget.onSort(sortIndex),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 2),
                Icon(
                  widget.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 10,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withAlpha(100),
      child: Row(
        children: [
          const SizedBox(width: _kExpandW),
          _headerCell(context, 'First Name', 0, _kFirstNameW),
          _headerCell(context, 'Last Name', 1, _kLastNameW),
          _headerCell(context, 'Date Joined', 2, _kDateJoinedW),
          _headerCell(context, 'Status', 3, _kStatusW),
          _headerCell(context, 'Phone', 7, _kPhoneW),
          _headerCell(context, 'Woodworking', 10, _kWoodworkingW),
          _headerCell(context, 'Metalworking', 11, _kMetalworkingW),
          _headerCell(context, 'Gym Waiver', 12, _kGymWaiverW),
          const SizedBox(width: _kActionsW),
        ],
      ),
    );
  }

  // ── Rows ───────────────────────────────────────────────────────────────────

  Widget _buildRow(BuildContext context, _MemberRow row,
      {bool isPending = false}) {
    final key = row.id ?? '__new__';
    final isEditing = isPending || (_editing.contains(key) && widget.canEdit);

    if (isEditing) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x1F000000), width: 0.5),
          ),
        ),
        child: _buildEditPanel(context, row, key: key, isPending: isPending),
      );
    }

    final isExpanded = _expanded.contains(key);
    final isDirty = row.isDirty;

    return Container(
      decoration: BoxDecoration(
        color: isDirty
            ? Theme.of(context).colorScheme.tertiaryContainer.withAlpha(60)
            : null,
        border: const Border(
          bottom: BorderSide(color: Color(0x1F000000), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _toggleExpand(key),
                  child: SizedBox(
                    width: _kExpandW,
                    height: 48,
                    child: Center(
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _readCell(context, row.firstNameCtrl, _kFirstNameW),
                _readCell(context, row.lastNameCtrl, _kLastNameW),
                _readCell(context, row.dateJoinedCtrl, _kDateJoinedW),
                _readCell(context, row.statusCtrl, _kStatusW),
                _readCell(context, row.phoneCtrl, _kPhoneW),
                _readDateCell(context, row.woodworkingCtrl, _kWoodworkingW),
                _readDateCell(context, row.metalworkingCtrl, _kMetalworkingW),
                _readDateCell(context, row.gymWaiverCtrl, _kGymWaiverW),
                SizedBox(
                  width: _kActionsW,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.canEdit)
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          tooltip: 'Edit',
                          onPressed: () => _startEdit(key),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                      if (widget.canEdit)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.error),
                          tooltip: 'Delete',
                          onPressed: () => widget.onDelete(row),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              padding: const EdgeInsets.fromLTRB(_kExpandW, 6, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _subLabel(context, 'Street Address', 200),
                      const SizedBox(width: 12),
                      _subLabel(context, 'PO Box', 90),
                      const SizedBox(width: 12),
                      _subLabel(context, 'Email', 200),
                      const SizedBox(width: 12),
                      _subLabel(context, 'Date of Birth', 110),
                      const SizedBox(width: 12),
                      _subLabel(context, 'Emergency Contact', 180),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _readCell(context, row.streetCtrl, 200),
                      const SizedBox(width: 12),
                      _readCell(context, row.poBoxCtrl, 90),
                      const SizedBox(width: 12),
                      _readCell(context, row.emailCtrl, 200),
                      const SizedBox(width: 12),
                      _readDateCell(context, row.dobCtrl, 110),
                      const SizedBox(width: 12),
                      _readCell(context, row.emergencyCtrl, 180),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddLink(BuildContext context) {
    return InkWell(
      onTap: widget.onAddNew,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const SizedBox(width: _kExpandW),
            Icon(Icons.add,
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Add member',
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
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (widget.rows.isEmpty && widget.pendingRow == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(_kExpandW + 4, 24, 16, 24),
                child: Text('No members yet.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ...widget.rows.map((row) => _buildRow(context, row)),
            if (widget.pendingRow != null)
              _buildRow(context, widget.pendingRow!, isPending: true),
            if (widget.canEdit && widget.pendingRow == null)
              _buildAddLink(context),
          ],
        ),
      ),
    );
  }
}
