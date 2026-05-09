import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter/material.dart';

const String _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
const String _auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID');
const String _auth0Audience = String.fromEnvironment('AUTH0_AUDIENCE');

/// Displays the login screen with an Auth0 redirect sign-in button.
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
                  onPressed: () => _signIn(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _signIn() {
    final auth0 = Auth0Web(_auth0Domain, _auth0ClientId);
    final origin = '${Uri.base.scheme}://${Uri.base.host}'
        '${Uri.base.hasPort ? ":${Uri.base.port}" : ""}';
    auth0.loginWithRedirect(
      redirectUrl: origin,
      audience: _auth0Audience,
      scopes: {'openid', 'profile', 'email'},
    );
  }
}
