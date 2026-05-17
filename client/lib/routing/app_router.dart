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
import '../screens/pl_report_screen.dart';
import '../screens/monthly_report_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/general_ledger_screen.dart';
import '../screens/gst_management_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/bank_reconciliation_screen.dart';
import '../screens/locked_months_screen.dart';
import '../screens/login_screen.dart';
import '../screens/transactions_screen.dart';

/// Routes that contributors may not access.
const _contributorBlockedPaths = {
  '/admin/bank-accounts',
  '/admin/gst-management',
  '/admin/audit-log',
  '/admin/backup',
  '/admin/locked-months',
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

      // Contributors cannot navigate to restricted admin screens.
      if (authState.isContributor &&
          _contributorBlockedPaths.contains(state.uri.path)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => TransactionsScreen(
              initialContact: state.extra as ContactEntry?,
            ),
          ),
          GoRoute(
            path: '/bank-reconciliation',
            builder: (context, state) => const BankReconciliationScreen(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: '/reports/bas',
            builder: (context, state) => const BasReportScreen(),
          ),
          GoRoute(
            path: '/reports/pl',
            builder: (context, state) => const PlReportScreen(),
          ),
          GoRoute(
            path: '/reports/monthly',
            builder: (context, state) => const MonthlyReportScreen(),
          ),
          GoRoute(
            path: '/admin/entity',
            builder: (context, state) => const EntityScreen(),
          ),
          GoRoute(
            path: '/admin/bank-accounts',
            builder: (context, state) => const BankAccountsScreen(),
          ),
          GoRoute(
            path: '/admin/contacts',
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/admin/general-ledger',
            builder: (context, state) => const GeneralLedgerScreen(),
          ),
          GoRoute(
            path: '/admin/gst-management',
            builder: (context, state) => const GstManagementScreen(),
          ),
          GoRoute(
            path: '/admin/audit-log',
            builder: (context, state) => const AuditScreen(),
          ),
          GoRoute(
            path: '/admin/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/admin/locked-months',
            builder: (context, state) => const LockedMonthsScreen(),
          ),
        ],
      ),
    ],
  );
}
