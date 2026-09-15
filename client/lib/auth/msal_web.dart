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
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Parses a JSON string into a plain JS object/array — the standard trick
/// for building nested config/request objects for a JS SDK from Dart
/// without hand-chaining property sets for every nested field.
@JS('JSON.parse')
external JSAny? _jsonParse(String json);

@JS('msal.PublicClientApplication')
extension type _MsalApp._(JSObject _) implements JSObject {
  external _MsalApp(JSAny config);
  external JSPromise<JSAny?> initialize();
  external JSPromise<JSAny?> handleRedirectPromise();
  external JSPromise<JSAny?> loginRedirect(JSAny request);
  external JSPromise<JSAny?> acquireTokenSilent(JSAny request);
  external JSPromise<JSAny?> logoutRedirect(JSAny request);
  external JSArray<JSAny?> getAllAccounts();
  external void setActiveAccount(JSAny? account);
}

extension type _MsalAuthResult._(JSObject _) implements JSObject {
  external String? get accessToken;
  external JSObject? get account;
}

extension type _MsalAccount._(JSObject _) implements JSObject {
  external String? get username;
  external String? get name;
}

/// Result of an MSAL sign-in — just the fields [AuthState] needs, kept
/// independent of the underlying JS SDK's own types.
class MsalResult {
  final String accessToken;
  final String? accountName;
  final String? accountUsername;

  const MsalResult({
    required this.accessToken,
    this.accountName,
    this.accountUsername,
  });
}

/// Thin dart:js_interop wrapper around Microsoft's msal-browser SDK (loaded
/// via CDN in web/index.html), mirroring the shape auth0_flutter_web's
/// Auth0Web already presents to the rest of the app: a redirect-based
/// login, an [onLoad] that both completes a pending redirect and silently
/// restores an existing session, and a redirect-based logout.
class MsalWeb {
  final String clientId;
  final String tenantId;
  final String redirectUri;
  late final _MsalApp _app;

  MsalWeb({
    required this.clientId,
    required this.tenantId,
    required this.redirectUri,
  });

  /// Requesting the app's own API scope (rather than only `openid`/`profile`)
  /// is what makes the returned access token's audience this app — not
  /// Microsoft Graph — and carries the caller's assigned App Role.
  String get _scope => '$clientId/access_as_user';

  Future<void> initialize() async {
    final config = _jsonParse(jsonEncode({
      'auth': {
        'clientId': clientId,
        'authority': 'https://login.microsoftonline.com/$tenantId',
        'redirectUri': redirectUri,
      },
      'cache': {'cacheLocation': 'localStorage'},
    }))!;
    _app = _MsalApp(config);
    await _app.initialize().toDart;
  }

  /// Completes a pending redirect response if present, otherwise attempts a
  /// silent token refresh for a previously-cached account. Returns null if
  /// neither applies — there is no Entra session to restore, which is the
  /// common case (not signed in, or signed in via Auth0 instead).
  Future<MsalResult?> onLoad() async {
    final redirectResult = await _app.handleRedirectPromise().toDart;
    if (redirectResult != null) {
      return _toResult(redirectResult as JSObject);
    }

    final accounts = _app.getAllAccounts().toDart;
    if (accounts.isEmpty) return null;

    final account = accounts.first;
    _app.setActiveAccount(account);

    final request = JSObject();
    request['scopes'] = [_scope.toJS].toJS;
    request['account'] = account;

    try {
      final silentResult = await _app.acquireTokenSilent(request).toDart;
      if (silentResult == null) return null;
      return _toResult(silentResult as JSObject);
    } catch (_) {
      // Silent refresh can fail (expired session, revoked consent, etc.) —
      // treat as "not signed in", matching Auth0Web.onLoad()'s own
      // catch-and-ignore in main.dart for the equivalent case.
      return null;
    }
  }

  Future<void> loginRedirect() async {
    final request = _jsonParse(jsonEncode({
      'scopes': [_scope],
    }))!;
    await _app.loginRedirect(request).toDart;
  }

  Future<void> logoutRedirect(String returnToUrl) async {
    final request = _jsonParse(jsonEncode({
      'postLogoutRedirectUri': returnToUrl,
    }))!;
    await _app.logoutRedirect(request).toDart;
  }

  MsalResult _toResult(JSObject raw) {
    final result = raw as _MsalAuthResult;
    final token = result.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('MSAL result had no access token');
    }
    final account = result.account as _MsalAccount?;
    return MsalResult(
      accessToken: token,
      accountName: account?.name,
      accountUsername: account?.username,
    );
  }
}
