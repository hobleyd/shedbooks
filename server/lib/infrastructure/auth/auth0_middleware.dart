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
          audience: Audience.one(audience),
        );

        final updatedRequest = request.change(
          context: {'auth.claims': jwt.payload},
        );
        return inner(updatedRequest);
      } on JWTExpiredException {
        return _unauthorised('Token has expired');
      } on JWTException catch (e) {
        return _unauthorised('Invalid token: ${e.message}');
      } catch (e) {
        return _unauthorised('Authentication failed');
      }
    };
  };
}

Response _unauthorised(String message) => Response.unauthorized(
      jsonEncode({'error': message}),
      headers: {'content-type': 'application/json'},
    );
