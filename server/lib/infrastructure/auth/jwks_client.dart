import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/pointycastle.dart' as pc;

/// Fetches and caches JSON Web Key Sets from an Auth0 domain.
class JwksClient {
  final String _auth0Domain;
  final http.Client _httpClient;

  // Cache keys for up to 1 hour to avoid hammering the JWKS endpoint.
  final Map<String, RSAPublicKey> _keyCache = {};
  DateTime? _cacheExpiry;

  JwksClient(this._auth0Domain, [http.Client? httpClient])
      : _httpClient = httpClient ?? http.Client();

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
    final uri = Uri.https(_auth0Domain, '/.well-known/jwks.json');
    final response = await _httpClient.get(uri);

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
