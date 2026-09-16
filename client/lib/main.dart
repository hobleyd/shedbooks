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

import 'auth/auth_state.dart';
import 'auth/msal_web.dart';
import 'routing/app_router.dart';
import 'services/api_client.dart';
import 'services/navigation_guard.dart';
import 'services/reference_data_cache.dart';

const String _entraTenantId = String.fromEnvironment('ENTRA_TENANT_ID');
const String _entraClientId = String.fromEnvironment('ENTRA_CLIENT_ID');
const String _apiUrl = String.fromEnvironment('API_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authState = AuthState();

  final msal = MsalWeb(
    clientId: _entraClientId,
    tenantId: _entraTenantId,
    redirectUri: '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.hasPort ? ":${Uri.base.port}" : ""}/',
  );
  try {
    await msal.initialize();
    final result = await msal.onLoad();
    if (result != null) {
      authState.setSession(
        accessToken: result.accessToken,
        user: AuthUser(name: result.accountName, email: result.accountUsername),
      );
    }
  } catch (e) {
    // ignore: avoid_print
    print('MSAL onLoad error: $e');
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
