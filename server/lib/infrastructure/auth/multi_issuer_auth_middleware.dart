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

import 'multi_issuer_jwt.dart';

/// Shelf middleware that accepts Bearer JWTs from any of one or more
/// configured issuers — this app used it to accept Auth0 and Entra ID
/// concurrently during the migration between them; Entra is now the only
/// entry in the map, but the dispatch mechanism is kept as-is since it's
/// exactly what a future second issuer would need again.
///
/// Dispatch is by the token's own (unverified) `iss` claim; the token is
/// only ever trusted once the [ClaimsVerifier] registered for that issuer
/// in [verifiersByIssuer] has actually verified its signature. A token
/// naming an issuer not present in the map is rejected outright.
///
/// On success, the verified/normalised claims are attached to the request
/// context under the key 'auth.claims'.
Middleware multiIssuerAuthMiddleware(
  Map<String, ClaimsVerifier> verifiersByIssuer,
) {
  return (Handler inner) {
    return (Request request) async {
      final authHeader = request.headers[HttpHeaders.authorizationHeader];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _unauthorised('Missing or invalid Authorization header');
      }

      final token = authHeader.substring(7);
      final issuer = peekIssuer(token);
      final verifier = issuer == null ? null : verifiersByIssuer[issuer];
      if (verifier == null) {
        return _unauthorised('Unknown token issuer');
      }

      // JWT validation is confined to this try/catch; inner(request) is
      // called after it returns normally, so a downstream handler error
      // propagates as itself rather than being caught here and misreported
      // as an authentication failure.
      final Map<String, dynamic> claims;
      try {
        claims = await verifier(token);
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
