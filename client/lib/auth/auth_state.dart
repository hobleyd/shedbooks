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

/// Display-only profile fields, populated from whichever identity provider
/// authenticated the user.
class AuthUser {
  final String? name;
  final String? email;

  const AuthUser({this.name, this.email});
}

/// Holds the current authentication state and notifies listeners on change.
///
/// Deliberately independent of any auth SDK's own types — login_screen.dart
/// and main.dart are the only places that touch MsalWeb directly; everything
/// else here just reads accessToken/user/role.
class AuthState extends ChangeNotifier {
  String? _accessToken;
  AuthUser? _user;

  bool get isAuthenticated => _accessToken != null;

  String? get accessToken => _accessToken;

  AuthUser? get user => _user;

  /// Decodes and returns the access token's JWT payload, or null if there
  /// is no token or it isn't shaped like a JWT.
  Map<String, dynamic>? get _payload {
    final token = _accessToken;
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// The user's highest-privilege role decoded from the access token.
  ///
  /// Defaults to [AppRole.viewer] when no role claim is present, ensuring
  /// no privilege is granted by omission.
  AppRole get role {
    final raw = _payload?['roles'];
    final roles = raw is List ? raw : <dynamic>[];
    return AppRole.fromList(roles);
  }

  /// Entra's own `oid` claim — the same object id server-side code reads as
  /// `sub` (see request_identity.dart's `resolveUserId`) and
  /// `UserPresence.userId`. Used to compare "is this me" against a Users
  /// screen row without relying on email, which can differ between the
  /// server's resolved claim and MSAL's account object for the same person.
  String? get userId => _payload?['oid'] as String?;

  /// True for [AppRole.contributor] and [AppRole.administrator].
  bool get canEdit => role.atLeast(AppRole.contributor);

  /// True only for [AppRole.administrator].
  bool get isAdmin => role == AppRole.administrator;

  /// True when the user is a [AppRole.contributor] (used to hide admin-only
  /// screens that contributors cannot access).
  bool get isContributor => role == AppRole.contributor;

  /// Updates the session and notifies listeners.
  void setSession({required String accessToken, required AuthUser user}) {
    _accessToken = accessToken;
    _user = user;
    notifyListeners();
  }

  /// Clears the session and notifies listeners.
  void clearCredentials() {
    _accessToken = null;
    _user = null;
    notifyListeners();
  }
}
