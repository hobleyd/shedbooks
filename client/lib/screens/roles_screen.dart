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
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/app_role.dart';
import '../models/permission_action.dart';
import '../models/permission_page.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';
import '../services/permission_service.dart';

class _PageCellState {
  bool isOverride;
  bool canRead;
  bool canWrite;
  _PageCellState({required this.isOverride, required this.canRead, required this.canWrite});
}

class _ActionCellState {
  bool isOverride;
  bool canPerform;
  _ActionCellState({required this.isOverride, required this.canPerform});
}

/// Lets an administrator configure, per role, which pages the app allows
/// reading/writing, and — for a handful of action buttons that can
/// legitimately diverge from their page's write access — override those
/// independently. See CLAUDE.md's Roles/Permissions section and
/// `server/lib/infrastructure/database/migrations/062_add_role_permissions.sql`.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _isDirty = false;
  String? _loadError;
  bool _isTemplateEntity = false;

  final Map<PermissionPage, Map<AppRole, _PageCellState>> _pageCells = {};
  final Map<PermissionAction, Map<AppRole, _ActionCellState>> _actionCells = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      final client = context.read<ApiClient>();
      final res = await client.get('/roles/permissions');
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      _pageCells.clear();
      for (final raw in json['pages'] as List) {
        final row = raw as Map<String, dynamic>;
        final page = PermissionPage.fromKey(row['page'] as String);
        final role = AppRole.values.byName(row['role'] as String);
        (_pageCells[page] ??= {})[role] = _PageCellState(
          isOverride: row['isOverride'] as bool,
          canRead: row['canRead'] as bool,
          canWrite: row['canWrite'] as bool,
        );
      }
      _actionCells.clear();
      for (final raw in json['actions'] as List) {
        final row = raw as Map<String, dynamic>;
        final action = PermissionAction.fromKey(row['action'] as String);
        final role = AppRole.values.byName(row['role'] as String);
        (_actionCells[action] ??= {})[role] = _ActionCellState(
          isOverride: row['isOverride'] as bool,
          canPerform: row['canPerform'] as bool,
        );
      }

      setState(() {
        _isTemplateEntity = json['isTemplateEntity'] as bool;
        _isDirty = false;
        _loading = false;
      });
      context.read<NavigationGuard>().setDirty(false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  void _markDirty() {
    if (_isDirty) return;
    setState(() => _isDirty = true);
    context.read<NavigationGuard>().setDirty(true);
  }

  bool _isRolesLockCell(PermissionPage page, AppRole role) =>
      page == PermissionPage.adminRoles && role == AppRole.administrator;

  /// On the template entity, every cell IS the global default — there is no
  /// layer above it to "inherit" from, so unlike a normal entity, unchecking
  /// "Custom" here doesn't fall back to a broader default, it deletes the
  /// only row that exists, silently widening that cell for every entity that
  /// doesn't already override it (e.g. unchecking Custom on
  /// transactions-import/contributor would let contributors import bank
  /// statements everywhere). So the toggle is always locked on here.
  bool get _customLockedForTemplate => _isTemplateEntity;

  Future<void> _discard() => _load();

  Future<void> _save() async {
    setState(() => _saving = true);

    final pages = [
      for (final entry in _pageCells.entries)
        for (final roleEntry in entry.value.entries)
          if (roleEntry.value.isOverride)
            {
              'page': entry.key.key,
              'role': roleEntry.key.name,
              'canRead': roleEntry.value.canRead,
              'canWrite': roleEntry.value.canWrite,
            },
    ];
    final actions = [
      for (final entry in _actionCells.entries)
        for (final roleEntry in entry.value.entries)
          if (roleEntry.value.isOverride)
            {
              'action': entry.key.key,
              'role': roleEntry.key.name,
              'canPerform': roleEntry.value.canPerform,
            },
    ];

    try {
      final client = context.read<ApiClient>();
      final res = await client.put(
        '/roles/permissions',
        jsonEncode({'pages': pages, 'actions': actions}),
      );
      if (!mounted) return;
      if (res.statusCode != 204) {
        setState(() => _saving = false);
        _showSnackbar(_errorMessage(res.body, res.statusCode));
        return;
      }
      // Refresh this session's own effective permissions immediately so
      // testing a change doesn't require signing out and back in.
      await context.read<PermissionService>().refresh();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnackbar('Save failed: $e');
      }
    }
  }

  String _errorMessage(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'Save failed ($statusCode)';
    } catch (_) {
      return 'Save failed ($statusCode)';
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
            if (!_loading && _loadError == null) ...[
              const SizedBox(height: 8),
              _buildTemplateBanner(),
            ],
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
        Text('Roles', style: Theme.of(context).textTheme.headlineMedium),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save'),
          ),
        ],
      ],
    );
  }

  Widget _buildTemplateBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            _isTemplateEntity ? Icons.public : Icons.business,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isTemplateEntity
                  ? 'This is the platform template entity — changes here also become the default for future entities.'
                  : 'These settings apply only to this entity. Future entities inherit the platform default instead.',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      children: [
        _buildGroupSection('General', PermissionPageGroup.main),
        _buildGroupSection('Reports', PermissionPageGroup.reports),
        _buildGroupSection('Administration', PermissionPageGroup.admin),
      ],
    );
  }

  Widget _buildGroupSection(String title, PermissionPageGroup group) {
    final pages = PermissionPage.values.where((p) => p.group == group).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(height: 16),
          for (final page in pages) _buildPageCard(page),
        ],
      ),
    );
  }

  Widget _buildPageCard(PermissionPage page) {
    final actions = PermissionAction.values.where((a) => a.page == page).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(page.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final role in AppRole.values)
                  Expanded(child: _buildPageRoleCell(page, role)),
              ],
            ),
            for (final action in actions) ...[
              const Divider(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(action.label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final role in AppRole.values)
                    Expanded(child: _buildActionRoleCell(action, role)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageRoleCell(PermissionPage page, AppRole role) {
    final cell = _pageCells[page]?[role];
    if (cell == null) return const SizedBox.shrink();
    final fullyLocked = _isRolesLockCell(page, role);
    final customLocked = fullyLocked || _customLockedForTemplate;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_roleLabel(role), style: Theme.of(context).textTheme.labelMedium),
          Tooltip(
            message: fullyLocked
                ? 'Administrators must always be able to read and write the Roles page'
                : _customLockedForTemplate
                    ? 'The platform template always sets every cell explicitly'
                    : 'Set independently of the platform default',
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Custom', style: TextStyle(fontSize: 12)),
              value: cell.isOverride,
              onChanged: (customLocked || _saving)
                  ? null
                  : (v) => setState(() {
                        cell.isOverride = v ?? false;
                        _markDirty();
                      }),
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Read', style: TextStyle(fontSize: 12)),
            value: cell.canRead,
            onChanged: (fullyLocked || _saving || !cell.isOverride)
                ? null
                : (v) => setState(() {
                      cell.canRead = v ?? false;
                      _markDirty();
                    }),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Write', style: TextStyle(fontSize: 12)),
            value: cell.canWrite,
            onChanged: (fullyLocked || _saving || !cell.isOverride)
                ? null
                : (v) => setState(() {
                      cell.canWrite = v ?? false;
                      _markDirty();
                    }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRoleCell(PermissionAction action, AppRole role) {
    final cell = _actionCells[action]?[role];
    if (cell == null) return const SizedBox.shrink();
    final customLocked = _customLockedForTemplate;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_roleLabel(role), style: Theme.of(context).textTheme.labelMedium),
          Tooltip(
            message: customLocked
                ? 'The platform template always sets every action explicitly'
                : 'Set independently of the page\'s write access',
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Custom', style: TextStyle(fontSize: 12)),
              value: cell.isOverride,
              onChanged: (customLocked || _saving)
                  ? null
                  : (v) => setState(() {
                        cell.isOverride = v ?? false;
                        _markDirty();
                      }),
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Allowed', style: TextStyle(fontSize: 12)),
            value: cell.canPerform,
            onChanged: (_saving || !cell.isOverride)
                ? null
                : (v) => setState(() {
                      cell.canPerform = v ?? false;
                      _markDirty();
                    }),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(AppRole role) => switch (role) {
        AppRole.viewer => 'Viewer',
        AppRole.contributor => 'Contributor',
        AppRole.administrator => 'Administrator',
      };
}
