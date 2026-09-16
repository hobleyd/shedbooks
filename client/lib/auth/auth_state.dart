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

  /// The user's highest-privilege role decoded from the access token.
  ///
  /// Defaults to [AppRole.viewer] when no role claim is present, ensuring
  /// no privilege is granted by omission.
  AppRole get role {
    final token = _accessToken;
    if (token == null) return AppRole.viewer;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return AppRole.viewer;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final raw = payload['roles'];
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
