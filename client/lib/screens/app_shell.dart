import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../widgets/app_sidebar.dart';

const String _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
const String _auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID');

/// Shell layout wrapping all authenticated screens with an AppBar and sidebar.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShedBooks'),
        actions: [
          if (authState.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  authState.user!.name ?? authState.user!.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context, authState),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AuthState authState) async {
    final auth0 = Auth0Web(_auth0Domain, _auth0ClientId);
    authState.clearCredentials();
    await auth0.logout(returnToUrl: 'https://shedbooks.sharpblue.com.au');
    if (context.mounted) context.go('/');
  }
}
