import 'package:go_router/go_router.dart';

import '../auth/auth_state.dart';
import '../screens/app_shell.dart';
import '../screens/bank_accounts_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/entity_screen.dart';
import '../screens/bas_report_screen.dart';
import '../screens/pl_report_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/general_ledger_screen.dart';
import '../screens/gst_management_screen.dart';
import '../screens/login_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/transactions_screen.dart';

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
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/bank-reconciliation',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Bank Reconciliation'),
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
        ],
      ),
    ],
  );
}
