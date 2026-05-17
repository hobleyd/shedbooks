import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/auth_state.dart';
import 'routing/app_router.dart';
import 'services/api_client.dart';
import 'services/navigation_guard.dart';

const String _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
const String _auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID');
const String _auth0Audience = String.fromEnvironment('AUTH0_AUDIENCE');
const String _apiUrl = String.fromEnvironment('API_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authState = AuthState();

  final auth0 = Auth0Web(_auth0Domain, _auth0ClientId);
  try {
    final credentials = await auth0.onLoad(
      audience: _auth0Audience,
      scopes: {'openid', 'profile', 'email'},
    );
    if (credentials != null) authState.setCredentials(credentials);
  } catch (e) {
    // ignore: avoid_print
    print('Auth0 onLoad error: $e');
  }

  final router = createRouter(authState);

  final apiClient = ApiClient(
    baseUrl: _apiUrl,
    getToken: () => authState.accessToken,
    onUnauthorized: authState.clearCredentials,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        Provider.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => NavigationGuard()),
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
    );
  }
}
