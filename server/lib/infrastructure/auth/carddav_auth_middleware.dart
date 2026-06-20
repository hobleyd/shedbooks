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

import 'jwks_client.dart';

/// Shelf middleware that validates Auth0 JWTs for CardDAV endpoints.
///
/// Accepts the JWT in either:
/// - `Authorization: Bearer <jwt>` — standard API usage.
/// - `Authorization: Basic base64(username:<jwt>)` — for CardDAV clients
///   (e.g. iOS Contacts) that only support HTTP Basic Auth; the JWT is used as
///   the password, and the username field is ignored.
///
/// On success, the decoded JWT payload is attached to the request context under
/// `'auth.claims'`, matching the behaviour of [auth0Middleware].
Middleware cardDavAuthMiddleware({
  required String auth0Domain,
  required String audience,
  required JwksClient jwksClient,
}) {
  return (Handler inner) {
    return (Request request) async {
      final token = _extractToken(request);
      if (token == null) {
        return Response.unauthorized(
          jsonEncode({'error': 'Missing or invalid Authorization header'}),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            'WWW-Authenticate':
                'Basic realm="Shedbooks Members", Bearer realm="Shedbooks"',
          },
        );
      }

      try {
        final headerPart = token.split('.').first;
        final headerJson = utf8.decode(
          base64Url.decode(base64Url.normalize(headerPart)),
        );
        final header = jsonDecode(headerJson) as Map<String, dynamic>;
        final kid = header['kid'] as String?;
        if (kid == null) {
          return _unauthorised('JWT header missing kid');
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
          return _unauthorised('Invalid token: invalid audience');
        }

        return inner(
          request.change(context: {'auth.claims': jwt.payload}),
        );
      } on JWTExpiredException {
        return _unauthorised('Token has expired');
      } on JWTException catch (e) {
        return _unauthorised('Invalid token: ${e.message}');
      } catch (_) {
        return _unauthorised('Authentication failed');
      }
    };
  };
}

/// Extracts the raw JWT string from either Bearer or Basic auth header.
String? _extractToken(Request request) {
  final authHeader = request.headers[HttpHeaders.authorizationHeader];
  if (authHeader == null) return null;

  if (authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }

  if (authHeader.startsWith('Basic ')) {
    final encoded = authHeader.substring(6).trim();
    try {
      final decoded = utf8.decode(base64.decode(encoded));
      // Format: username:password — password is the JWT.
      final colonIdx = decoded.indexOf(':');
      if (colonIdx < 0) return null;
      final password = decoded.substring(colonIdx + 1).trim();
      return password.isEmpty ? null : password;
    } catch (_) {
      return null;
    }
  }

  return null;
}

Response _unauthorised(String message) => Response.unauthorized(
      jsonEncode({'error': message}),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        'WWW-Authenticate':
            'Basic realm="Shedbooks Members", Bearer realm="Shedbooks"',
      },
    );
