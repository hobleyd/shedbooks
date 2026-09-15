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

import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/auth_state.dart';
import 'auth/msal_web.dart';
import 'routing/app_router.dart';
import 'services/api_client.dart';
import 'services/navigation_guard.dart';
import 'services/reference_data_cache.dart';

const String _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
const String _auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID');
const String _auth0Audience = String.fromEnvironment('AUTH0_AUDIENCE');
const String _entraTenantId = String.fromEnvironment('ENTRA_TENANT_ID');
const String _entraClientId = String.fromEnvironment('ENTRA_CLIENT_ID');
const String _apiUrl = String.fromEnvironment('API_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authState = AuthState();

  // Sequenced, not run concurrently: both auth0-spa-js and msal-browser
  // inspect the current URL/session storage for a pending redirect
  // response on page load, and each only completes its own callback (state
  // param mismatches for the other are ignored) — but running them
  // concurrently would still race on reading/clearing window.location.
  // Auth0 goes first only because it's been the primary provider longest;
  // once Auth0 is retired this reduces to just the Entra branch.
  final auth0 = Auth0Web(_auth0Domain, _auth0ClientId);
  var signedIn = false;
  try {
    final credentials = await auth0.onLoad(
      audience: _auth0Audience,
      scopes: {'openid', 'profile', 'email'},
    );
    if (credentials != null) {
      authState.setSession(
        accessToken: credentials.accessToken,
        user: AuthUser(
          name: credentials.user.name,
          email: credentials.user.email,
        ),
        issuer: AuthIssuer.auth0,
      );
      signedIn = true;
    }
  } catch (e) {
    // ignore: avoid_print
    print('Auth0 onLoad error: $e');
  }

  final msal = MsalWeb(
    clientId: _entraClientId,
    tenantId: _entraTenantId,
    redirectUri: '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.hasPort ? ":${Uri.base.port}" : ""}/',
  );
  if (!signedIn && _entraClientId.isNotEmpty && _entraTenantId.isNotEmpty) {
    try {
      await msal.initialize();
      final result = await msal.onLoad();
      if (result != null) {
        authState.setSession(
          accessToken: result.accessToken,
          user:
              AuthUser(name: result.accountName, email: result.accountUsername),
          issuer: AuthIssuer.entra,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('MSAL onLoad error: $e');
    }
  }

  final router = createRouter(authState);

  final apiClient = ApiClient(
    baseUrl: _apiUrl,
    getToken: () => authState.accessToken,
    onUnauthorized: authState.clearCredentials,
  );

  final referenceDataCache = ReferenceDataCache(apiClient);
  authState.addListener(() {
    if (!authState.isAuthenticated) referenceDataCache.reset();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        Provider.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => NavigationGuard()),
        ChangeNotifierProvider.value(value: referenceDataCache),
      ],
      child: ShedbooksApp(router: router),
    ),
  );
}

class ShedbooksApp extends StatelessWidget {
  final GoRouter router;

  const ShedbooksApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ShedBooks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (BuildContext context, Widget? child) =>
          SelectionArea(child: child ?? const SizedBox.shrink()),
    );
  }
}
