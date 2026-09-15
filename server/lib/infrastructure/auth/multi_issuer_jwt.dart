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

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../../domain/repositories/i_entity_details_repository.dart';
import 'jwks_client.dart';

/// Verifies a raw JWT string and returns its claims, or throws
/// [JWTExpiredException]/[JWTException] on failure — the shape every
/// issuer-specific verifier below (and any caller dispatching between them)
/// agrees on.
typedef ClaimsVerifier = Future<Map<String, dynamic>> Function(String token);

/// Reads the (unverified) `iss` claim out of a JWT's payload, for dispatch
/// purposes only — the issuer named here is never trusted until the
/// corresponding [ClaimsVerifier] has verified the token's signature
/// against that issuer's own keys. Returns null for a malformed token.
String? peekIssuer(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payloadJson = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    return payload['iss'] as String?;
  } catch (_) {
    return null;
  }
}

/// Verifies an Auth0-issued JWT and returns its raw claims. Auth0's claim
/// shape (`https://shedbooks.com/entity_id`, `sub`, `email`,
/// `https://shedbooks.com/roles`) is already this app's canonical shape, so
/// no normalisation is needed — unlike [EntraJwtVerifier].
Future<Map<String, dynamic>> verifyAuth0Jwt(
  String token, {
  required String auth0Domain,
  required String audience,
  required JwksClient jwksClient,
}) async {
  final headerPart = token.split('.').first;
  final headerJson = utf8.decode(
    base64Url.decode(base64Url.normalize(headerPart)),
  );
  final header = jsonDecode(headerJson) as Map<String, dynamic>;
  final kid = header['kid'] as String?;
  if (kid == null) {
    throw JWTInvalidException('JWT header missing kid');
  }

  final publicKey = await jwksClient.getPublicKey(kid);
  final jwt = JWT.verify(token, publicKey, issuer: 'https://$auth0Domain/');

  // dart_jsonwebtoken does strict list equality for audience, but Auth0
  // access tokens carry multiple audiences (API + /userinfo). Check
  // manually that our audience is present in the aud claim.
  final payload = jwt.payload as Map<String, dynamic>;
  final rawAud = payload['aud'];
  final audList = rawAud is List
      ? rawAud.cast<String>()
      : rawAud is String
          ? [rawAud]
          : <String>[];
  if (!audList.contains(audience)) {
    throw JWTInvalidException('invalid audience');
  }

  return payload;
}

/// Verifies a Microsoft Entra ID (v2.0) JWT for a single expected tenant
/// and normalises it into the same claim keys [verifyAuth0Jwt] produces, so
/// every downstream consumer (`resolveEntityId`, `resolveUserId`,
/// `resolveEmail`, `roleFromRequest`) needs no knowledge of which issuer
/// authenticated the caller.
///
/// Verified against a *single* tenant deliberately (single-tenant App
/// Registration + an explicit `tid` check, not just issuer string matching)
/// — this app does not (yet) support multiple Entra tenants.
///
/// Entity resolution: Entra's `tid` claim is resolved to this app's
/// `entity_id` via `entity_details.entra_tenant_id` (migration 059). A
/// resolved (non-null) result is cached for the life of this instance,
/// since that mapping cannot change without a schema edit. A null result
/// (no entity configured for this tenant yet) is deliberately *not*
/// cached — it's retried on every request, so configuring the column in
/// the database takes effect immediately without a server restart.
class EntraJwtVerifier {
  EntraJwtVerifier({
    required this.tenantId,
    required this.clientId,
    required this.jwksClient,
    required this.entityDetailsRepository,
  }) : issuer = 'https://login.microsoftonline.com/$tenantId/v2.0';

  final String tenantId;
  final String clientId;
  final JwksClient jwksClient;
  final IEntityDetailsRepository entityDetailsRepository;
  final String issuer;

  String? _cachedEntityId;

  /// Matches [ClaimsVerifier]'s signature, so an instance can be used
  /// anywhere a `Future<Map<String, dynamic>> Function(String)` is expected.
  Future<Map<String, dynamic>> call(String token) async {
    final headerPart = token.split('.').first;
    final headerJson = utf8.decode(
      base64Url.decode(base64Url.normalize(headerPart)),
    );
    final header = jsonDecode(headerJson) as Map<String, dynamic>;
    final kid = header['kid'] as String?;
    if (kid == null) {
      throw JWTInvalidException('JWT header missing kid');
    }

    final publicKey = await jwksClient.getPublicKey(kid);
    final jwt = JWT.verify(token, publicKey, issuer: issuer);
    final claims = jwt.payload as Map<String, dynamic>;

    final rawAud = claims['aud'];
    final audList = rawAud is List
        ? rawAud.cast<String>()
        : rawAud is String
            ? [rawAud]
            : <String>[];
    if (!audList.contains(clientId)) {
      throw JWTInvalidException('invalid audience');
    }

    // Belt-and-braces alongside the issuer check above — this app only
    // ever expects tokens from the one tenant it was registered in.
    if (claims['tid'] != tenantId) {
      throw JWTInvalidException('unexpected tenant');
    }

    _cachedEntityId ??=
        await entityDetailsRepository.findEntityIdByEntraTenantId(tenantId);
    final entityId = _cachedEntityId;
    if (entityId == null) {
      // No entity has this Entra tenant configured — never let a null
      // entity_id flow downstream, since several handlers would read that
      // as "no tenant filter" rather than "reject this caller".
      throw JWTInvalidException('no entity configured for this tenant');
    }

    return normaliseEntraClaims(claims, entityId);
  }
}

/// Normalises already-verified Entra claims into the same claim keys
/// [verifyAuth0Jwt] produces. Split out from [EntraJwtVerifier.call] so the
/// mapping — the part that decides which tenant's data and which identity a
/// caller ends up as — can be unit tested directly against a captured token
/// payload, without needing a real RS256 signature to reach it.
Map<String, dynamic> normaliseEntraClaims(
  Map<String, dynamic> claims,
  String entityId,
) {
  // oid (stable, unique per user) rather than sub (v2.0 access tokens carry
  // a per-application pairwise sub, not a stable cross-app identity).
  final oid = claims['oid'];
  if (oid is! String || oid.isEmpty) {
    throw JWTInvalidException('missing oid claim');
  }

  return {
    'https://shedbooks.com/entity_id': entityId,
    'sub': oid,
    'email': resolveEntraEmail(claims),
    'https://shedbooks.com/roles': claims['roles'] ?? <dynamic>[],
  };
}

/// Entra v2.0 tokens don't always carry an `email` claim (only when the
/// "email" optional claim is configured and the account has one) — fall
/// back through `preferred_username` (present whenever the `profile` scope
/// is granted) and finally `upn` before giving up.
String resolveEntraEmail(Map<String, dynamic> claims) {
  final email = claims['email'] as String?;
  if (email != null && email.isNotEmpty) return email;

  final preferredUsername = claims['preferred_username'] as String?;
  if (preferredUsername != null && preferredUsername.isNotEmpty) {
    return preferredUsername;
  }

  return (claims['upn'] as String?) ?? '';
}
