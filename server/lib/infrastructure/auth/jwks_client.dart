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
import 'dart:typed_data';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/pointycastle.dart' as pc;

/// Fetches and caches JSON Web Keys from one or more issuers' JWKS
/// endpoints — e.g. Auth0's `/.well-known/jwks.json` and Entra ID's
/// `/discovery/v2.0/keys`. Each [JwksClient] instance is bound to a single
/// JWKS URI; callers that need to accept multiple issuers (Auth0 and Entra
/// concurrently) hold one instance per issuer, keyed by issuer in the
/// dispatch layer above this class — this class itself stays single-issuer
/// so it has no knowledge of *how* issuers are told apart.
class JwksClient {
  final Uri _jwksUri;
  final http.Client _httpClient;

  // Cache keys for up to 1 hour to avoid hammering the JWKS endpoint.
  final Map<String, RSAPublicKey> _keyCache = {};
  DateTime? _cacheExpiry;

  JwksClient(String auth0Domain, [http.Client? httpClient])
      : _jwksUri = Uri.https(auth0Domain, '/.well-known/jwks.json'),
        _httpClient = httpClient ?? http.Client();

  /// Creates a client fetching keys from an arbitrary JWKS [uri] — used for
  /// issuers (e.g. Entra ID) whose JWKS endpoint isn't Auth0's fixed
  /// `/.well-known/jwks.json` path under a domain.
  JwksClient.forUri(Uri uri, [http.Client? httpClient])
      : _jwksUri = uri,
        _httpClient = httpClient ?? http.Client();

  /// Returns the RSA public key matching [kid].
  /// Refreshes the cache when it has expired or the key is not found.
  Future<RSAPublicKey> getPublicKey(String kid) async {
    if (_isCacheValid() && _keyCache.containsKey(kid)) {
      return _keyCache[kid]!;
    }

    await _refreshCache();

    final key = _keyCache[kid];
    if (key == null) {
      throw Exception('No JWKS key found for kid: $kid');
    }
    return key;
  }

  bool _isCacheValid() =>
      _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!);

  Future<void> _refreshCache() async {
    final response = await _httpClient.get(_jwksUri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch JWKS: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final keys = body['keys'] as List<dynamic>;

    _keyCache.clear();

    for (final key in keys) {
      final jwk = key as Map<String, dynamic>;
      if (jwk['kty'] != 'RSA' || jwk['use'] != 'sig') continue;

      final kid = jwk['kid'] as String;
      _keyCache[kid] = _rsaPublicKeyFromJwk(jwk);
    }

    _cacheExpiry = DateTime.now().add(const Duration(hours: 1));
  }

  RSAPublicKey _rsaPublicKeyFromJwk(Map<String, dynamic> jwk) {
    final nBytes = _base64UrlDecode(jwk['n'] as String);
    final eBytes = _base64UrlDecode(jwk['e'] as String);

    final modulus = _bigIntFromBytes(nBytes);
    final exponent = _bigIntFromBytes(eBytes);

    final pcKey = pc.RSAPublicKey(modulus, exponent);
    return RSAPublicKey.raw(pcKey);
  }

  static Uint8List _base64UrlDecode(String input) {
    // Pad to a multiple of 4 characters.
    final padded = input.padRight((input.length + 3) ~/ 4 * 4, '=');
    return base64Url.decode(padded);
  }

  static BigInt _bigIntFromBytes(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}
