import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/navigation_guard.dart';

/// Persistent left navigation sidebar for authenticated screens.
class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key});

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

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _NavItem(
            label: 'Bank Reconciliation',
            icon: Icons.account_balance_outlined,
            path: '/bank-reconciliation',
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
    (label: 'BAS Report', icon: Icons.receipt_long_outlined, path: '/reports/bas'),
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

  static const _subItems = [
    (label: 'Entity', icon: Icons.business_outlined, path: '/admin/entity'),
    (label: 'Bank Accounts', icon: Icons.account_balance_outlined, path: '/admin/bank-accounts'),
    (label: 'Contacts', icon: Icons.people_outlined, path: '/admin/contacts'),
    (label: 'General Ledger', icon: Icons.book_outlined, path: '/admin/general-ledger'),
    (label: 'GST Management', icon: Icons.percent_outlined, path: '/admin/gst-management'),
    (label: 'Backup', icon: Icons.backup_outlined, path: '/admin/backup'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdminActive = currentPath.startsWith('/admin');

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
        children: _subItems.map((item) {
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
