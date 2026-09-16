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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../auth/msal_web.dart';
import '../widgets/app_sidebar.dart';

const String _entraTenantId = String.fromEnvironment('ENTRA_TENANT_ID');
const String _entraClientId = String.fromEnvironment('ENTRA_CLIENT_ID');

/// Shell layout wrapping all authenticated screens with a sidebar.
///
/// Hosts the [StatefulNavigationShell] from go_router so each screen's State
/// (filters, scroll position, controllers, in-progress workflows) is retained
/// across navigation rather than being torn down and rebuilt.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSidebar(onSignOut: () => _signOut(context, authState)),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AuthState authState) async {
    final origin = '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.hasPort ? ":${Uri.base.port}" : ""}';
    authState.clearCredentials();

    final msal = MsalWeb(
      clientId: _entraClientId,
      tenantId: _entraTenantId,
      redirectUri: '$origin/',
    );
    await msal.initialize();
    await msal.logoutRedirect(origin);
    if (context.mounted) context.go('/');
  }
}
