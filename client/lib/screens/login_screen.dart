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

import '../auth/msal_web.dart';

const String _entraTenantId = String.fromEnvironment('ENTRA_TENANT_ID');
const String _entraClientId = String.fromEnvironment('ENTRA_CLIENT_ID');

/// Displays the login screen with a Microsoft (Entra ID) redirect sign-in
/// button.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ShedBooks',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bookkeeping made simple',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () => _signInWithMicrosoft(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('Sign in with Microsoft'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithMicrosoft() async {
    final origin = '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.hasPort ? ":${Uri.base.port}" : ""}/';
    final msal = MsalWeb(
      clientId: _entraClientId,
      tenantId: _entraTenantId,
      redirectUri: origin,
    );
    await msal.initialize();
    await msal.loginRedirect();
  }
}
