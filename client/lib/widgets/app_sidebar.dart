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
import '../auth/auth_state.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';

/// Persistent left navigation sidebar for authenticated screens.
class AppSidebar extends StatefulWidget {
  final VoidCallback? onSignOut;

  const AppSidebar({super.key, this.onSignOut});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

/// Navigates to [path], first prompting the user if there are unsaved changes.
Future<void> _guardedNavigate(BuildContext context, String path) async {
  final guard = context.read<NavigationGuard>();
  if (guard.isDirty) {
    final leave = await showDialog<bool>(
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
    if (leave != true) return;
    guard.setDirty(false);
  }
  if (context.mounted) context.go(path);
}

class _AppSidebarState extends State<AppSidebar> {
  bool _adminExpanded = false;
  bool _reportsExpanded = false;
  String? _entityName;

  @override
  void initState() {
    super.initState();
    _fetchEntityName();
  }

  Future<void> _fetchEntityName() async {
    try {
      final client = context.read<ApiClient>();
      final res = await client.get('/entity-details');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _entityName = data['name'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/admin')) _adminExpanded = true;
    if (path.startsWith('/reports')) _reportsExpanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final authState = context.watch<AuthState>();
    final userName = authState.user?.name ?? authState.user?.email ?? '';

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_entityName != null) ...[
            const SizedBox(height: 16),
            Text(
              _entityName!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Image.asset(
            'assets/logo.png',
            width: 240,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  _NavItem(
                    label: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    path: '/dashboard',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    label: 'Transactions',
                    icon: Icons.receipt_long_outlined,
                    path: '/transactions',
                    currentPath: currentPath,
                  ),
                  if (authState.isAdmin)
                    _NavItem(
                      label: 'Bank Reconciliation',
                      icon: Icons.account_balance_outlined,
                      path: '/bank-reconciliation',
                      currentPath: currentPath,
                    ),
                  _NavItem(
                    label: 'Invoices',
                    icon: Icons.description_outlined,
                    path: '/invoices',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    label: 'Members',
                    icon: Icons.badge_outlined,
                    path: '/members',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    label: 'Asset Register',
                    icon: Icons.inventory_2_outlined,
                    path: '/assets',
                    currentPath: currentPath,
                  ),
                  _ReportsNavGroup(
                    currentPath: currentPath,
                    expanded: _reportsExpanded,
                    onExpansionChanged: (v) => setState(() => _reportsExpanded = v),
                  ),
                  _AdminNavGroup(
                    currentPath: currentPath,
                    expanded: _adminExpanded,
                    onExpansionChanged: (expanded) =>
                        setState(() => _adminExpanded = expanded),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(
              userName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: widget.onSignOut,
            ),
            contentPadding: const EdgeInsets.only(left: 16, right: 4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String path;
  final String currentPath;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentPath == path;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? colorScheme.primary : null,
          fontWeight: isActive ? FontWeight.w600 : null,
        ),
      ),
      selected: isActive,
      selectedTileColor: colorScheme.primaryContainer.withAlpha(80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => _guardedNavigate(context, path),
    );
  }
}

class _ReportsNavGroup extends StatelessWidget {
  final String currentPath;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  const _ReportsNavGroup({
    required this.currentPath,
    required this.expanded,
    required this.onExpansionChanged,
  });

  static const _subItems = [
    (label: 'Assets', icon: Icons.inventory_2_outlined, path: '/reports/assets'),
    (label: 'BAS Report', icon: Icons.receipt_long_outlined, path: '/reports/bas'),
    (label: 'Budget', icon: Icons.account_balance_wallet_outlined, path: '/reports/budget'),
    (label: 'Financial Performance', icon: Icons.analytics_outlined, path: '/reports/financial-performance'),
    (label: 'P&L', icon: Icons.trending_up_outlined, path: '/reports/pl'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = currentPath.startsWith('/reports');

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          Icons.bar_chart_outlined,
          color: isActive ? colorScheme.primary : null,
        ),
        title: Text(
          'Reports',
          style: TextStyle(
            color: isActive ? colorScheme.primary : null,
            fontWeight: isActive ? FontWeight.w600 : null,
          ),
        ),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        children: _subItems.map((item) {
          final isItemActive = currentPath == item.path;
          return ListTile(
            leading: Icon(
              item.icon,
              size: 20,
              color: isItemActive ? colorScheme.primary : null,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                color: isItemActive ? colorScheme.primary : null,
                fontWeight: isItemActive ? FontWeight.w600 : null,
              ),
            ),
            selected: isItemActive,
            selectedTileColor: colorScheme.primaryContainer.withAlpha(80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.only(left: 40, right: 16),
            onTap: () => _guardedNavigate(context, item.path),
          );
        }).toList(),
      ),
    );
  }
}

class _AdminNavGroup extends StatelessWidget {
  final String currentPath;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  const _AdminNavGroup({
    required this.currentPath,
    required this.expanded,
    required this.onExpansionChanged,
  });

  static const _allSubItems = [
    (label: 'Audit Log', icon: Icons.history_outlined, path: '/admin/audit-log'),
    (label: 'Backup', icon: Icons.backup_outlined, path: '/admin/backup'),
    (label: 'Bank Accounts', icon: Icons.account_balance_outlined, path: '/admin/bank-accounts'),
    (label: 'Contacts', icon: Icons.people_outlined, path: '/admin/contacts'),
    (label: 'Entity', icon: Icons.business_outlined, path: '/admin/entity'),
    (label: 'General Ledger', icon: Icons.book_outlined, path: '/admin/general-ledger'),
    (label: 'GST Management', icon: Icons.percent_outlined, path: '/admin/gst-management'),
    (label: 'Locked Months', icon: Icons.lock_outlined, path: '/admin/locked-months'),
  ];

  // Visible to administrators only; hidden from viewers and contributors.
  static const _adminOnlySubItems = [
    (label: 'Users', icon: Icons.manage_accounts_outlined, path: '/admin/users'),
  ];

  // Paths hidden from contributors.
  static const _contributorHidden = {
    '/admin/audit-log',
    '/admin/backup',
    '/admin/bank-accounts',
    '/admin/gst-management',
    '/admin/locked-months',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdminActive = currentPath.startsWith('/admin');
    final role = context.watch<AuthState>().role;
    final List<({String label, IconData icon, String path})> subItems;
    if (role == AppRole.administrator) {
      subItems = [..._allSubItems, ..._adminOnlySubItems];
    } else if (role == AppRole.contributor) {
      subItems = _allSubItems
          .where((i) => !_contributorHidden.contains(i.path))
          .toList();
    } else {
      subItems = [];
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          Icons.admin_panel_settings_outlined,
          color: isAdminActive ? colorScheme.primary : null,
        ),
        title: Text(
          'Admin',
          style: TextStyle(
            color: isAdminActive ? colorScheme.primary : null,
            fontWeight: isAdminActive ? FontWeight.w600 : null,
          ),
        ),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        children: subItems.map((item) {
          final isActive = currentPath == item.path;
          return ListTile(
            leading: Icon(
              item.icon,
              size: 20,
              color: isActive ? colorScheme.primary : null,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                color: isActive ? colorScheme.primary : null,
                fontWeight: isActive ? FontWeight.w600 : null,
              ),
            ),
            selected: isActive,
            selectedTileColor: colorScheme.primaryContainer.withAlpha(80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.only(left: 40, right: 16),
            onTap: () => _guardedNavigate(context, item.path),
          );
        }).toList(),
      ),
    );
  }
}
