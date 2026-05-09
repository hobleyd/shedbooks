import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/foundation.dart';

/// Holds the current authentication state and notifies listeners on change.
class AuthState extends ChangeNotifier {
  Credentials? _credentials;

  bool get isAuthenticated => _credentials != null;

  String? get accessToken => _credentials?.accessToken;

  UserProfile? get user => _credentials?.user;

  /// Updates credentials and notifies listeners.
  void setCredentials(Credentials credentials) {
    _credentials = credentials;
    notifyListeners();
  }

  /// Clears credentials and notifies listeners.
  void clearCredentials() {
    _credentials = null;
    notifyListeners();
  }
}
