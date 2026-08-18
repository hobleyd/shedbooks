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
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../../domain/repositories/i_user_api_key_repository.dart';
import '../encryption/sha256_hex.dart';
import 'jwks_client.dart';

/// Shelf middleware that authenticates CardDAV endpoints.
///
/// Accepts credentials in three forms:
/// - `Authorization: Bearer <jwt>` — standard JWT Bearer token.
/// - `Authorization: Basic base64(username:<jwt>)` — for CardDAV clients
///   (e.g. iOS Contacts) that only support HTTP Basic Auth; the JWT is used as
///   the password, and the username field is ignored.
/// - `Authorization: Basic base64(email:<api-key>)` — when [apiKeyRepository]
///   is provided; the API key is looked up by its SHA-256 hash and the username
///   must match the stored email (case-insensitive).
///
/// On success, the decoded claims are attached to the request context under
/// `'auth.claims'`, matching the behaviour of [auth0Middleware].
Middleware cardDavAuthMiddleware({
  required String auth0Domain,
  required String audience,
  required JwksClient jwksClient,
  IUserApiKeyRepository? apiKeyRepository,
}) {
  return (Handler inner) {
    return (Request request) async {
      final auth = _extractAuth(request);
      if (auth == null) {
        return _unauthorized();
      }

      final password = auth.password;

      if (_looksLikeJwt(password)) {
        return _verifyJwt(
          token: password,
          auth0Domain: auth0Domain,
          audience: audience,
          jwksClient: jwksClient,
          inner: inner,
          request: request,
        );
      }

      // Not a JWT — try API key lookup if a repository was supplied.
      if (auth.username != null && apiKeyRepository != null) {
        return _verifyApiKey(
          username: auth.username!,
          rawKey: password,
          repository: apiKeyRepository,
          inner: inner,
          request: request,
        );
      }

      return _unauthorized();
    };
  };
}

// ── Private helpers ────────────────────────────────────────────────────────

/// Holds credentials extracted from the Authorization header.
typedef _AuthCredentials = ({String? username, String password});

/// Extracts credentials from a Bearer or Basic Authorization header.
///
/// Returns `(username: null, password: token)` for Bearer, or
/// `(username: u, password: p)` for Basic, or null when the header is absent
/// or malformed.
_AuthCredentials? _extractAuth(Request request) {
  final authHeader = request.headers[HttpHeaders.authorizationHeader];
  if (authHeader == null) return null;

  if (authHeader.startsWith('Bearer ')) {
    final token = authHeader.substring(7).trim();
    return token.isEmpty ? null : (username: null, password: token);
  }

  if (authHeader.startsWith('Basic ')) {
    final encoded = authHeader.substring(6).trim();
    try {
      final decoded = utf8.decode(base64.decode(encoded));
      final colonIdx = decoded.indexOf(':');
      if (colonIdx < 0) return null;
      final username = decoded.substring(0, colonIdx);
      final password = decoded.substring(colonIdx + 1).trim();
      return password.isEmpty ? null : (username: username, password: password);
    } catch (_) {
      return null;
    }
  }

  return null;
}

/// Returns true when [s] looks like a three-part JWT (header.payload.signature).
bool _looksLikeJwt(String s) {
  final parts = s.split('.');
  return parts.length == 3 && parts.every((p) => p.isNotEmpty);
}

Future<Response> _verifyJwt({
  required String token,
  required String auth0Domain,
  required String audience,
  required JwksClient jwksClient,
  required Handler inner,
  required Request request,
}) async {
  // JWT validation is confined to this try/catch; inner(request) is called
  // after it returns normally, so a downstream handler error propagates as
  // itself rather than being caught here and misreported as an auth failure.
  final Map<String, dynamic>? claims;
  try {
    final headerPart = token.split('.').first;
    final headerJson = utf8.decode(
      base64Url.decode(base64Url.normalize(headerPart)),
    );
    final header = jsonDecode(headerJson) as Map<String, dynamic>;
    final kid = header['kid'] as String?;
    if (kid == null) {
      return _unauthorizedMessage('JWT header missing kid');
    }

    final publicKey = await jwksClient.getPublicKey(kid);
    final jwt = JWT.verify(
      token,
      publicKey,
      issuer: 'https://$auth0Domain/',
    );

    final payload = jwt.payload as Map<String, dynamic>?;
    final rawAud = payload?['aud'];
    final audList = rawAud is List
        ? rawAud.cast<String>()
        : rawAud is String
            ? [rawAud]
            : <String>[];
    if (!audList.contains(audience)) {
      return _unauthorizedMessage('Invalid token: invalid audience');
    }

    claims = jwt.payload;
  } on JWTExpiredException {
    return _unauthorizedMessage('Token has expired');
  } on JWTException catch (e) {
    return _unauthorizedMessage('Invalid token: ${e.message}');
  } catch (_) {
    return _unauthorizedMessage('Authentication failed');
  }

  return inner(request.change(context: {'auth.claims': claims}));
}

Future<Response> _verifyApiKey({
  required String username,
  required String rawKey,
  required IUserApiKeyRepository repository,
  required Handler inner,
  required Request request,
}) async {
  // API key lookup is confined to this try/catch; inner(request) is called
  // after it returns normally, so a downstream handler error propagates as
  // itself rather than being caught here and misreported as an auth failure.
  final Map<String, dynamic> claims;
  try {
    final hash = sha256Hex(rawKey);
    final key = await repository.findByApiKeyHash(hash);

    if (key == null) return _unauthorizedMessage('Invalid API key');

    // Username must match the stored email (case-insensitive).
    if (username.toLowerCase() != key.userEmail.toLowerCase()) {
      return _unauthorizedMessage('Username does not match API key');
    }

    claims = {
      'https://shedbooks.com/entity_id': key.entityId,
      'sub': key.userId,
      'email': key.userEmail,
    };
  } catch (_) {
    return _unauthorizedMessage('Authentication failed');
  }

  return inner(request.change(context: {'auth.claims': claims}));
}

Response _unauthorized() => Response.unauthorized(
      jsonEncode({'error': 'Missing or invalid Authorization header'}),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        // Advertise only Basic — adding Bearer causes macOS/iOS to attempt
        // OAuth discovery, which fails and reports "Unable to verify account
        // or password" even when valid credentials are supplied.
        'WWW-Authenticate': 'Basic realm="Shedbooks Members"',
      },
    );

Response _unauthorizedMessage(String message) => Response.unauthorized(
      jsonEncode({'error': message}),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        'WWW-Authenticate': 'Basic realm="Shedbooks Members"',
      },
    );
