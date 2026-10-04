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
/// Roles admin screen. [key] is the stable identifier persisted in
/// `role_page_permission_defaults` / `entity_page_permission_overrides` —
/// keep it in sync with the client's mirrored `PermissionPage` registry in
/// `client/lib/models/permission_page.dart`.
enum PermissionPage {
  dashboard('dashboard'),
  transactions('transactions'),
  bankReconciliation('bank-reconciliation'),
  invoices('invoices'),
  members('members'),
  assets('assets'),
  capexRequests('capex-requests'),
  reportsAssets('reports-assets'),
  reportsBas('reports-bas'),
  reportsPl('reports-pl'),
  reportsBudget('reports-budget'),
  reportsMonthly('reports-monthly'),
  reportsFinancialPerformance('reports-financial-performance'),
  adminEntity('admin-entity'),
  adminBankAccounts('admin-bank-accounts'),
  adminContacts('admin-contacts'),
  adminGeneralLedger('admin-general-ledger'),
  adminGstManagement('admin-gst-management'),
  adminAuditLog('admin-audit-log'),
  adminBackup('admin-backup'),
  adminLockedMonths('admin-locked-months'),
  adminUsers('admin-users'),
  adminO365Sync('admin-o365-sync'),
  adminRoles('admin-roles');

  final String key;
  const PermissionPage(this.key);

  static PermissionPage fromKey(String key) => values.firstWhere(
        (p) => p.key == key,
        orElse: () => throw FormatException('Unknown page key: $key'),
      );
}
