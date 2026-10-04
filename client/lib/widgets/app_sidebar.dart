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

import '../auth/auth_state.dart';
import '../models/permission_page.dart';
import '../screens/api_key_dialog.dart';
import '../services/api_client.dart';
import '../services/navigation_guard.dart';
import '../services/permission_service.dart';

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

enum _UserMenuAction { apiKey }

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

  void _handleUserMenuAction(BuildContext context, _UserMenuAction action) {
    switch (action) {
      case _UserMenuAction.apiKey:
        showDialog<void>(
          context: context,
          builder: (_) => const ApiKeyDialog(),
        );
    }
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
    final permissions = context.watch<PermissionService>();
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
                  if (permissions.canReadPage(PermissionPage.dashboard))
                    _NavItem(
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      path: '/dashboard',
                      currentPath: currentPath,
                    ),
                  if (permissions.canReadPage(PermissionPage.transactions))
                    _NavItem(
                      label: 'Transactions',
                      icon: Icons.receipt_long_outlined,
                      path: '/transactions',
                      currentPath: currentPath,
                    ),
                  if (permissions.canReadPage(PermissionPage.bankReconciliation))
                    _NavItem(
                      label: 'Bank Reconciliation',
                      icon: Icons.account_balance_outlined,
                      path: '/bank-reconciliation',
                      currentPath: currentPath,
                    ),
                  if (permissions.canReadPage(PermissionPage.invoices))
                    _NavItem(
                      label: 'Invoices',
                      icon: Icons.description_outlined,
                      path: '/invoices',
                      currentPath: currentPath,
                    ),
                  if (permissions.canReadPage(PermissionPage.capexRequests))
                    _NavItem(
                      label: 'Capex Requests',
                      icon: Icons.request_quote_outlined,
                      path: '/capex-requests',
                      currentPath: currentPath,
                    ),
                  if (permissions.canReadPage(PermissionPage.members))
                    _NavItem(
                      label: 'Members',
                      icon: Icons.badge_outlined,
                      path: '/members',
                      currentPath: currentPath,
                    ),
                  if (permissions.canReadPage(PermissionPage.assets))
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
                    permissions: permissions,
                  ),
                  _AdminNavGroup(
                    currentPath: currentPath,
                    expanded: _adminExpanded,
                    onExpansionChanged: (expanded) =>
                        setState(() => _adminExpanded = expanded),
                    permissions: permissions,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: authState.canEdit
                ? PopupMenuButton<_UserMenuAction>(
                    tooltip: 'Account options',
                    child: const Icon(Icons.account_circle_outlined),
                    onSelected: (action) =>
                        _handleUserMenuAction(context, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _UserMenuAction.apiKey,
                        child: Row(children: [
                          Icon(Icons.vpn_key_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('API Key'),
                        ]),
                      ),
                    ],
                  )
                : const Icon(Icons.account_circle_outlined),
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
  final PermissionService permissions;

  const _ReportsNavGroup({
    required this.currentPath,
    required this.expanded,
    required this.onExpansionChanged,
    required this.permissions,
  });

  static const _allSubItems = [
    (label: 'Assets', icon: Icons.inventory_2_outlined, path: '/reports/assets', page: PermissionPage.reportsAssets),
    (label: 'BAS Report', icon: Icons.receipt_long_outlined, path: '/reports/bas', page: PermissionPage.reportsBas),
    (label: 'Budget', icon: Icons.account_balance_wallet_outlined, path: '/reports/budget', page: PermissionPage.reportsBudget),
    (label: 'Financial Performance', icon: Icons.analytics_outlined, path: '/reports/financial-performance', page: PermissionPage.reportsFinancialPerformance),
    (label: 'P&L', icon: Icons.trending_up_outlined, path: '/reports/pl', page: PermissionPage.reportsPl),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = currentPath.startsWith('/reports');
    final subItems =
        _allSubItems.where((i) => permissions.canReadPage(i.page)).toList();

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
        children: subItems.map((item) {
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
  final PermissionService permissions;

  const _AdminNavGroup({
    required this.currentPath,
    required this.expanded,
    required this.onExpansionChanged,
    required this.permissions,
  });

  static const _allSubItems = [
    (label: 'Audit Log', icon: Icons.history_outlined, path: '/admin/audit-log', page: PermissionPage.adminAuditLog),
    (label: 'Backup', icon: Icons.backup_outlined, path: '/admin/backup', page: PermissionPage.adminBackup),
    (label: 'Bank Accounts', icon: Icons.account_balance_outlined, path: '/admin/bank-accounts', page: PermissionPage.adminBankAccounts),
    (label: 'Contacts', icon: Icons.people_outlined, path: '/admin/contacts', page: PermissionPage.adminContacts),
    (label: 'Entity', icon: Icons.business_outlined, path: '/admin/entity', page: PermissionPage.adminEntity),
    (label: 'General Ledger', icon: Icons.book_outlined, path: '/admin/general-ledger', page: PermissionPage.adminGeneralLedger),
    (label: 'GST Management', icon: Icons.percent_outlined, path: '/admin/gst-management', page: PermissionPage.adminGstManagement),
    (label: 'Locked Months', icon: Icons.lock_outlined, path: '/admin/locked-months', page: PermissionPage.adminLockedMonths),
    (label: 'O365 Sync', icon: Icons.sync_outlined, path: '/admin/o365-sync', page: PermissionPage.adminO365Sync),
    (label: 'Roles', icon: Icons.admin_panel_settings_outlined, path: '/admin/roles', page: PermissionPage.adminRoles),
    (label: 'Users', icon: Icons.manage_accounts_outlined, path: '/admin/users', page: PermissionPage.adminUsers),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdminActive = currentPath.startsWith('/admin');
    final subItems =
        _allSubItems.where((i) => permissions.canReadPage(i.page)).toList();

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
