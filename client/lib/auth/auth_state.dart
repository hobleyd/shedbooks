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

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_role.dart';

/// Which identity provider issued the current session — needed only to pick
/// the matching logout flow (each SDK owns its own redirect-based sign-out).
enum AuthIssuer { auth0, entra }

/// Display-only profile fields, normalised across issuers so the rest of
/// the app never needs to know which one authenticated the user.
class AuthUser {
  final String? name;
  final String? email;

  const AuthUser({this.name, this.email});
}

/// Holds the current authentication state and notifies listeners on change.
///
/// Deliberately independent of any single auth SDK's own types (previously
/// held auth0_flutter's `Credentials` directly) — both Auth0 and Entra ID
/// logins normalise into accessToken/user/issuer here, so login_screen.dart
/// and main.dart are the only places that touch either SDK directly.
class AuthState extends ChangeNotifier {
  String? _accessToken;
  AuthUser? _user;
  AuthIssuer? _issuer;

  bool get isAuthenticated => _accessToken != null;

  String? get accessToken => _accessToken;

  AuthUser? get user => _user;

  /// Which provider issued the current session — null when signed out.
  AuthIssuer? get issuer => _issuer;

  /// The user's highest-privilege role decoded from the access token.
  ///
  /// Defaults to [AppRole.viewer] when no role claim is present, ensuring
  /// no privilege is granted by omission. Checks both the Auth0 namespaced
  /// claim and Entra's own unnamespaced `roles` claim (App Roles) — unlike
  /// the server, the client reads the raw token straight from whichever SDK
  /// issued it, so it sees each issuer's native shape, not a normalised one.
  AppRole get role {
    final token = _accessToken;
    if (token == null) return AppRole.viewer;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return AppRole.viewer;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final raw = payload['https://shedbooks.com/roles'] ?? payload['roles'];
      final roles = raw is List ? raw : <dynamic>[];
      return AppRole.fromList(roles);
    } catch (_) {
      return AppRole.viewer;
    }
  }

  /// True for [AppRole.contributor] and [AppRole.administrator].
  bool get canEdit => role.atLeast(AppRole.contributor);

  /// True only for [AppRole.administrator].
  bool get isAdmin => role == AppRole.administrator;

  /// True when the user is a [AppRole.contributor] (used to hide admin-only
  /// screens that contributors cannot access).
  bool get isContributor => role == AppRole.contributor;

  /// Updates the session and notifies listeners.
  void setSession({
    required String accessToken,
    required AuthUser user,
    required AuthIssuer issuer,
  }) {
    _accessToken = accessToken;
    _user = user;
    _issuer = issuer;
    notifyListeners();
  }

  /// Clears the session and notifies listeners.
  void clearCredentials() {
    _accessToken = null;
    _user = null;
    _issuer = null;
    notifyListeners();
  }
}
