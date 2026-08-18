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

/// Shelf middleware that validates Auth0 Bearer JWTs on every request.
///
/// On success, the decoded JWT payload is attached to the request context
/// under the key 'auth.claims'.
Middleware auth0Middleware({
  required String auth0Domain,
  required String audience,
  required JwksClient jwksClient,
}) {
  return (Handler inner) {
    return (Request request) async {
      final authHeader = request.headers[HttpHeaders.authorizationHeader];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _unauthorised('Missing or invalid Authorization header');
      }

      final token = authHeader.substring(7);

      // JWT validation is confined to this try/catch; inner(request) is
      // called after it returns normally, so a downstream handler error
      // propagates as itself rather than being caught here and misreported
      // as an authentication failure.
      final Map<String, dynamic>? claims;
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

        // dart_jsonwebtoken does strict list equality for audience, but Auth0
        // access tokens carry multiple audiences (API + /userinfo). Check
        // manually that our audience is present in the aud claim.
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

        claims = jwt.payload;
      } on JWTExpiredException {
        return _unauthorised('Token has expired');
      } on JWTException catch (e) {
        return _unauthorised('Invalid token: ${e.message}');
      } catch (e) {
        return _unauthorised('Authentication failed');
      }

      final updatedRequest = request.change(context: {'auth.claims': claims});
      return inner(updatedRequest);
    };
  };
}

Response _unauthorised(String message) => Response.unauthorized(
      jsonEncode({'error': message}),
      headers: {'content-type': 'application/json'},
    );
