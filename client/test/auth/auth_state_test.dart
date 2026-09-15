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

import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/auth/app_role.dart';
import 'package:shedbooks_client/auth/auth_state.dart';

/// Builds a fake (unsigned) JWT string carrying [payload] — AuthState never
/// verifies the signature client-side (the server does that), it only
/// decodes the payload for role/display purposes, so a real signature
/// isn't needed to exercise that logic.
String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'none'})))
      .replaceAll('=', '');
  final body =
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$header.$body.sig';
}

void main() {
  group('AuthState.role', () {
    test('defaults to viewer when not authenticated', () {
      final authState = AuthState();
      expect(authState.role, equals(AppRole.viewer));
    });

    test('reads Auth0\'s namespaced roles claim', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: _fakeJwt({
          'https://shedbooks.com/roles': ['administrator']
        }),
        user: const AuthUser(),
        issuer: AuthIssuer.auth0,
      );
      expect(authState.role, equals(AppRole.administrator));
    });

    test('reads Entra\'s unnamespaced roles claim', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: _fakeJwt({
          'roles': ['contributor']
        }),
        user: const AuthUser(),
        issuer: AuthIssuer.entra,
      );
      expect(authState.role, equals(AppRole.contributor));
    });

    test('defaults to viewer when neither roles claim is present', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: _fakeJwt({'sub': '1'}),
        user: const AuthUser(),
        issuer: AuthIssuer.entra,
      );
      expect(authState.role, equals(AppRole.viewer));
    });

    test('defaults to viewer for a malformed token', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: 'not-a-jwt',
        user: const AuthUser(),
        issuer: AuthIssuer.auth0,
      );
      expect(authState.role, equals(AppRole.viewer));
    });
  });

  group('AuthState session lifecycle', () {
    test('setSession populates isAuthenticated/user/issuer', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: _fakeJwt({
          'roles': ['viewer']
        }),
        user: const AuthUser(name: 'David Hobley', email: 'david@example.com'),
        issuer: AuthIssuer.entra,
      );

      expect(authState.isAuthenticated, isTrue);
      expect(authState.user?.name, equals('David Hobley'));
      expect(authState.user?.email, equals('david@example.com'));
      expect(authState.issuer, equals(AuthIssuer.entra));
    });

    test('clearCredentials resets everything', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: _fakeJwt({
          'roles': ['administrator']
        }),
        user: const AuthUser(name: 'David Hobley'),
        issuer: AuthIssuer.auth0,
      );

      authState.clearCredentials();

      expect(authState.isAuthenticated, isFalse);
      expect(authState.accessToken, isNull);
      expect(authState.user, isNull);
      expect(authState.issuer, isNull);
      expect(authState.role, equals(AppRole.viewer));
    });

    test('canEdit/isAdmin/isContributor derive from role', () {
      final authState = AuthState();
      authState.setSession(
        accessToken: _fakeJwt({
          'roles': ['contributor']
        }),
        user: const AuthUser(),
        issuer: AuthIssuer.entra,
      );

      expect(authState.canEdit, isTrue);
      expect(authState.isContributor, isTrue);
      expect(authState.isAdmin, isFalse);
    });
  });
}
