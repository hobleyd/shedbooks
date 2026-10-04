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

/// Every page in the application whose read/write access is governed by the
/// Roles admin screen. [key] must match the server's `PermissionPage.key`
/// (`server/lib/domain/enums/permission_page.dart`) exactly — the two
/// registries are kept in sync by hand, the same as this app's `AppRole`.
enum PermissionPage {
  dashboard('dashboard', 'Dashboard', PermissionPageGroup.main, '/dashboard'),
  transactions('transactions', 'Transactions', PermissionPageGroup.main, '/transactions'),
  bankReconciliation('bank-reconciliation', 'Bank Reconciliation',
      PermissionPageGroup.main, '/bank-reconciliation'),
  invoices('invoices', 'Invoices', PermissionPageGroup.main, '/invoices'),
  members('members', 'Members', PermissionPageGroup.main, '/members'),
  assets('assets', 'Asset Register', PermissionPageGroup.main, '/assets'),
  capexRequests('capex-requests', 'Capex Requests', PermissionPageGroup.main, '/capex-requests'),
  reportsAssets('reports-assets', 'Assets', PermissionPageGroup.reports, '/reports/assets'),
  reportsBas('reports-bas', 'BAS Report', PermissionPageGroup.reports, '/reports/bas'),
  reportsPl('reports-pl', 'P&L', PermissionPageGroup.reports, '/reports/pl'),
  reportsBudget('reports-budget', 'Budget', PermissionPageGroup.reports, '/reports/budget'),
  reportsMonthly(
      'reports-monthly', 'Monthly Report', PermissionPageGroup.reports, '/reports/monthly'),
  reportsFinancialPerformance('reports-financial-performance', 'Financial Performance',
      PermissionPageGroup.reports, '/reports/financial-performance'),
  adminEntity('admin-entity', 'Entity', PermissionPageGroup.admin, '/admin/entity'),
  adminBankAccounts(
      'admin-bank-accounts', 'Bank Accounts', PermissionPageGroup.admin, '/admin/bank-accounts'),
  adminContacts('admin-contacts', 'Contacts', PermissionPageGroup.admin, '/admin/contacts'),
  adminGeneralLedger('admin-general-ledger', 'General Ledger', PermissionPageGroup.admin,
      '/admin/general-ledger'),
  adminGstManagement('admin-gst-management', 'GST Management', PermissionPageGroup.admin,
      '/admin/gst-management'),
  adminAuditLog('admin-audit-log', 'Audit Log', PermissionPageGroup.admin, '/admin/audit-log'),
  adminBackup('admin-backup', 'Backup', PermissionPageGroup.admin, '/admin/backup'),
  adminLockedMonths('admin-locked-months', 'Locked Months', PermissionPageGroup.admin,
      '/admin/locked-months'),
  adminUsers('admin-users', 'Users', PermissionPageGroup.admin, '/admin/users'),
  adminO365Sync('admin-o365-sync', 'O365 Sync', PermissionPageGroup.admin, '/admin/o365-sync'),
  adminRoles('admin-roles', 'Roles', PermissionPageGroup.admin, '/admin/roles');

  final String key;
  final String label;
  final PermissionPageGroup group;

  /// The client route path this page corresponds to, or null when the page
  /// has no dedicated route of its own (none currently do, but a future
  /// page-only-on-server entry would leave this null).
  final String? path;

  const PermissionPage(this.key, this.label, this.group, this.path);

  static PermissionPage fromKey(String key) =>
      values.firstWhere((p) => p.key == key);

  /// The registered page whose [path] matches [routePath], or null if
  /// [routePath] isn't governed by the permission matrix (e.g. `/` or a
  /// path outside the authenticated shell).
  static PermissionPage? forPath(String routePath) {
    for (final page in values) {
      if (page.path == routePath) return page;
    }
    return null;
  }
}

/// Section grouping used to lay out the Roles screen's page list.
enum PermissionPageGroup { main, reports, admin }
