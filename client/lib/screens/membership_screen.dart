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

import 'package:excel/excel.dart';
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
  bool _addingMember = false;
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
    setState(() => _addingMember = true);
    _updateDirty();
  }

  Future<void> _saveNewMember(Map<String, dynamic> body) async {
    setState(() => _saving = true);
    try {
      final client = context.read<ApiClient>();
      final res = await client.post('/members', jsonEncode(body));
      if (res.statusCode == 201) {
        setState(() => _addingMember = false);
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
    final hasDirty = _addingMember || _rows.any((r) => r.isDirty);
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
            onAdd: canEdit && !_addingMember ? _addRow : null,
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_addingMember)
                          _AddMemberPanel(
                            isSaving: _saving,
                            onSave: _saveNewMember,
                            onCancel: () {
                              setState(() => _addingMember = false);
                              _updateDirty();
                            },
                          ),
                        if (_rows.isEmpty && !_addingMember)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('No members yet.'),
                                  if (canEdit) ...[
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _addRow,
                                      child: const Text('Add member'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else if (_rows.isNotEmpty)
                          Expanded(
                            child: _MemberTable(
                              rows: _rows,
                              canEdit: canEdit,
                              onSave: _saveRow,
                              onDelete: _deleteRow,
                              onChanged: _updateDirty,
                              sortColumn: _sortColumn,
                              sortAscending: _sortAscending,
                              onSort: _onSort,
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Toolbar ────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback? onAdd;
  final VoidCallback? onImport;
  final VoidCallback? onRefresh;

  const _Toolbar({this.onAdd, this.onImport, this.onRefresh});

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
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add member'),
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Table ──────────────────────────────────────────────────────────────────

class _MemberTable extends StatelessWidget {
  final List<_MemberRow> rows;
  final bool canEdit;
  final Future<void> Function(_MemberRow) onSave;
  final Future<void> Function(_MemberRow) onDelete;
  final VoidCallback onChanged;
  final int? sortColumn;
  final bool sortAscending;
  final void Function(int col) onSort;

  const _MemberTable({
    required this.rows,
    required this.canEdit,
    required this.onSave,
    required this.onDelete,
    required this.onChanged,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  // Column indices that can be sorted (excludes the trailing actions column).
  static const _sortableCount = 13;

  static const _columnLabels = [
    'First Name',
    'Last Name',
    'Date Joined',
    'Status',
    'Street Address',
    'PO Box',
    'Email',
    'Phone',
    'Date of Birth',
    'Emergency Contact',
    'Woodworking Induction',
    'Metalworking Induction',
    'Gym Waiver',
    '', // actions — not sortable
  ];

  DataColumn _col(BuildContext context, String label, int index) {
    if (index >= _sortableCount) {
      return const DataColumn(label: SizedBox.shrink());
    }
    final isActive = sortColumn == index;
    return DataColumn(
      label: InkWell(
        onTap: () => onSort(index),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Row(
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
                  sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 60,
          columns: _columnLabels
              .asMap()
              .entries
              .map((e) => _col(context, e.value, e.key))
              .toList(),
          rows: rows.map((row) => _buildRow(context, row)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, _MemberRow row) {
    Widget cell(TextEditingController ctrl, {double width = 130}) {
      if (!canEdit) {
        return SizedBox(
          width: width,
          child: Text(ctrl.text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        );
      }
      return SizedBox(
        width: width,
        child: TextFormField(
          controller: ctrl,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 4),
          ),
          onChanged: (_) => onChanged(),
        ),
      );
    }

    final isDirty = row.isDirty;

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (isDirty) {
          return Theme.of(context).colorScheme.tertiaryContainer.withAlpha(60);
        }
        return null;
      }),
      cells: [
        DataCell(
          SizedBox(
            width: 130,
            child: canEdit
                ? TextFormField(
                    controller: row.firstNameCtrl,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: (_) => onChanged(),
                  )
                : Text(row.firstNameCtrl.text,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        DataCell(
          SizedBox(
            width: 140,
            child: canEdit
                ? TextFormField(
                    controller: row.lastNameCtrl,
                    focusNode: row.lastNameFocus,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: (_) => onChanged(),
                  )
                : Text(row.lastNameCtrl.text,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        DataCell(cell(row.dateJoinedCtrl, width: 100)),
        DataCell(cell(row.statusCtrl, width: 80)),
        DataCell(cell(row.streetCtrl, width: 180)),
        DataCell(cell(row.poBoxCtrl, width: 80)),
        DataCell(cell(row.emailCtrl, width: 180)),
        DataCell(cell(row.phoneCtrl, width: 120)),
        DataCell(cell(row.dobCtrl, width: 100)),
        DataCell(cell(row.emergencyCtrl, width: 160)),
        DataCell(cell(row.woodworkingCtrl, width: 120)),
        DataCell(cell(row.metalworkingCtrl, width: 120)),
        DataCell(cell(row.gymWaiverCtrl, width: 100)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit && isDirty)
                IconButton(
                  icon: Icon(Icons.save_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Save',
                  onPressed: () => onSave(row),
                ),
              if (canEdit)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete',
                  onPressed: () => onDelete(row),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add Member Panel ───────────────────────────────────────────────────────

class _AddMemberPanel extends StatefulWidget {
  final bool isSaving;
  final void Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const _AddMemberPanel({
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_AddMemberPanel> createState() => _AddMemberPanelState();
}

class _AddMemberPanelState extends State<_AddMemberPanel> {
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _poBoxCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _dateJoinedCtrl = TextEditingController();
  final _dateOfBirthCtrl = TextEditingController();
  final _woodworkingCtrl = TextEditingController();
  final _metalworkingCtrl = TextEditingController();
  final _gymWaiverCtrl = TextEditingController();

  DateTime? _dateJoined;
  DateTime? _dateOfBirth;
  DateTime? _woodworking;
  DateTime? _metalworking;
  DateTime? _gymWaiver;

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _statusCtrl.dispose();
    _streetCtrl.dispose();
    _poBoxCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyCtrl.dispose();
    _dateJoinedCtrl.dispose();
    _dateOfBirthCtrl.dispose();
    _woodworkingCtrl.dispose();
    _metalworkingCtrl.dispose();
    _gymWaiverCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String? _isoDate(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  void _submit() {
    if (_lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last name is required')),
      );
      return;
    }
    widget.onSave({
      'lastName': _lastNameCtrl.text.trim(),
      'firstName': _firstNameCtrl.text.trim(),
      'dateJoined': _isoDate(_dateJoined),
      'membershipStatus':
          _statusCtrl.text.trim().isEmpty ? null : _statusCtrl.text.trim(),
      'streetAddress':
          _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
      'poBox': _poBoxCtrl.text.trim().isEmpty ? null : _poBoxCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'dateOfBirth': _isoDate(_dateOfBirth),
      'emergencyContact': _emergencyCtrl.text.trim().isEmpty
          ? null
          : _emergencyCtrl.text.trim(),
      'woodworkingInduction': _isoDate(_woodworking),
      'metalworkingInduction': _isoDate(_metalworking),
      'gymWaiver': _isoDate(_gymWaiver),
    });
  }

  static const _dec = InputDecoration(
    border: OutlineInputBorder(),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    floatingLabelBehavior: FloatingLabelBehavior.always,
  );

  Widget _textField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      enabled: !widget.isSaving,
      style: const TextStyle(fontSize: 13),
      decoration: _dec.copyWith(labelText: label),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    TextEditingController ctrl,
    DateTime firstDate,
    void Function(DateTime) onPicked,
    VoidCallback onClear,
  ) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      enabled: !widget.isSaving,
      style: const TextStyle(fontSize: 13),
      decoration: _dec.copyWith(
        labelText: label,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: widget.isSaving
                    ? null
                    : () => setState(() {
                          onClear();
                          ctrl.clear();
                        }),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.calendar_today, size: 16),
      ),
      onTap: widget.isSaving
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: firstDate,
                lastDate: DateTime(2060),
              );
              if (picked != null) {
                setState(() {
                  onPicked(picked);
                  ctrl.text = _fmt(picked);
                });
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'New Member',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.isSaving ? null : widget.onCancel,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 1: First Name | Last Name | Date Joined | Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _textField(_firstNameCtrl, 'First Name'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(_lastNameCtrl, 'Last Name *'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: _dateField(
                  'Date Joined',
                  _dateJoined,
                  _dateJoinedCtrl,
                  DateTime(2000),
                  (d) => _dateJoined = d,
                  () => _dateJoined = null,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: _textField(_statusCtrl, 'Status'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Street | PO Box | Email | Phone
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _textField(_streetCtrl, 'Street Address'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: _textField(_poBoxCtrl, 'PO Box'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(_emailCtrl, 'Email'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: _textField(_phoneCtrl, 'Phone'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 3: Date of Birth | Emergency Contact
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                child: _dateField(
                  'Date of Birth',
                  _dateOfBirth,
                  _dateOfBirthCtrl,
                  DateTime(1920),
                  (d) => _dateOfBirth = d,
                  () => _dateOfBirth = null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(_emergencyCtrl, 'Emergency Contact'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 4: Woodworking | Metalworking | Gym Waiver
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                child: _dateField(
                  'Woodworking Induction',
                  _woodworking,
                  _woodworkingCtrl,
                  DateTime(2000),
                  (d) => _woodworking = d,
                  () => _woodworking = null,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: _dateField(
                  'Metalworking Induction',
                  _metalworking,
                  _metalworkingCtrl,
                  DateTime(2000),
                  (d) => _metalworking = d,
                  () => _metalworking = null,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: _dateField(
                  'Gym Waiver',
                  _gymWaiver,
                  _gymWaiverCtrl,
                  DateTime(2000),
                  (d) => _gymWaiver = d,
                  () => _gymWaiver = null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buttons
          Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: widget.isSaving ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: widget.isSaving ? null : _submit,
                child: widget.isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
