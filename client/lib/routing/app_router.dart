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

import 'package:go_router/go_router.dart';

import '../auth/auth_state.dart';
import '../models/contact_entry.dart';
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
import '../screens/bank_reconciliation_screen.dart';
import '../screens/locked_months_screen.dart';
import '../screens/login_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/users_screen.dart';

/// Routes that contributors may not access.
const _contributorBlockedPaths = {
  '/admin/bank-accounts',
  '/admin/gst-management',
  '/admin/audit-log',
  '/admin/backup',
  '/admin/locked-months',
};

/// Routes restricted to administrators only (viewers and contributors are redirected).
const _administratorOnlyPaths = {
  '/admin/users',
};

/// Creates the application router with auth-based redirect guards.
GoRouter createRouter(AuthState authState) {
  return GoRouter(
    refreshListenable: authState,
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isOnLogin = state.uri.path == '/';

      if (!isAuthenticated && !isOnLogin) return '/';
      if (isAuthenticated && isOnLogin) return '/dashboard';

      // Viewers cannot navigate to any admin screen.
      if (!authState.canEdit &&
          state.uri.path.startsWith('/admin/')) {
        return '/dashboard';
      }

      // Contributors cannot navigate to restricted admin screens.
      if (authState.isContributor &&
          _contributorBlockedPaths.contains(state.uri.path)) {
        return '/dashboard';
      }

      // Administrator-only screens redirect everyone else.
      if (!authState.isAdmin &&
          _administratorOnlyPaths.contains(state.uri.path)) {
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
              builder: (context, state) => TransactionsScreen(
                initialContact: state.extra as ContactEntry?,
              ),
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
        ],
      ),
    ],
  );
}
