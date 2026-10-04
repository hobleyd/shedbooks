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

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_state.dart';
import '../models/contact_entry.dart';
import '../models/gl_pair_filter.dart';
import '../models/permission_page.dart';
import '../screens/app_shell.dart';
import '../screens/audit_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/bank_accounts_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/entity_screen.dart';
import '../screens/bas_report_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/pl_report_screen.dart';
import '../screens/financial_performance_screen.dart';
import '../screens/monthly_report_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/general_ledger_screen.dart';
import '../screens/gst_management_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/asset_register_screen.dart';
import '../screens/capex_requests_screen.dart';
import '../screens/asset_report_screen.dart';
import '../screens/membership_screen.dart';
import '../screens/bank_reconciliation_screen.dart';
import '../screens/locked_months_screen.dart';
import '../screens/login_screen.dart';
import '../screens/o365_settings_screen.dart';
import '../screens/roles_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/users_screen.dart';
import '../services/permission_service.dart';

/// Creates the application router with auth- and permission-based redirect
/// guards. Page access is driven by [permissionService] (`GET
/// /roles/effective`) rather than hardcoded role checks — see
/// `PermissionPage` and the Roles admin screen. Server-side route guards
/// remain the actual enforcement point; this only avoids showing a page the
/// user can't use.
GoRouter createRouter(AuthState authState, PermissionService permissionService) {
  return GoRouter(
    refreshListenable: Listenable.merge([authState, permissionService]),
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isOnLogin = state.uri.path == '/';

      if (!isAuthenticated && !isOnLogin) return '/';
      if (isAuthenticated && isOnLogin) return '/dashboard';

      // Dashboard is the universal post-login landing page and redirect
      // target, so it's deliberately exempt from the read check below —
      // gating it too could redirect a locked-out role to itself forever.
      final page = PermissionPage.forPath(state.uri.path);
      if (page != null &&
          page != PermissionPage.dashboard &&
          !permissionService.canReadPage(page)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      // Each authenticated screen lives in its own branch so its State is
      // retained across navigation (filters, scroll position, controllers,
      // in-progress workflows). go_router renders the branches inside an
      // IndexedStack and only swaps which one is visible.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) {
                final extra = state.extra;
                return TransactionsScreen(
                  initialContact: extra is ContactEntry ? extra : null,
                  initialGlPair: extra is GlPairFilter ? extra : null,
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bank-reconciliation',
              builder: (context, state) => const BankReconciliationScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/invoices',
              builder: (context, state) => const InvoicesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/members',
              builder: (context, state) => const MembershipScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/assets',
              builder: (context, state) => const AssetRegisterScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports/assets',
              builder: (context, state) => const AssetReportScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/capex-requests',
              builder: (context, state) => const CapexRequestsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports/bas',
              builder: (context, state) => const BasReportScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports/pl',
              builder: (context, state) => const PlReportScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports/budget',
              builder: (context, state) => const BudgetScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports/monthly',
              builder: (context, state) => const MonthlyReportScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports/financial-performance',
              builder: (context, state) =>
                  const FinancialPerformanceScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/entity',
              builder: (context, state) => const EntityScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/bank-accounts',
              builder: (context, state) => const BankAccountsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/contacts',
              builder: (context, state) => const ContactsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/general-ledger',
              builder: (context, state) => const GeneralLedgerScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/gst-management',
              builder: (context, state) => const GstManagementScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/audit-log',
              builder: (context, state) => const AuditScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/backup',
              builder: (context, state) => const BackupScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/locked-months',
              builder: (context, state) => const LockedMonthsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const UsersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/o365-sync',
              builder: (context, state) => const O365SettingsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/roles',
              builder: (context, state) => const RolesScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
}
