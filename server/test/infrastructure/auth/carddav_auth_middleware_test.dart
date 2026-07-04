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

import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/user_api_key.dart';
import 'package:shedbooks_server/domain/repositories/i_user_api_key_repository.dart';
import 'package:shedbooks_server/infrastructure/auth/carddav_auth_middleware.dart';
import 'package:shedbooks_server/infrastructure/auth/jwks_client.dart';
import 'package:shedbooks_server/infrastructure/encryption/sha256_hex.dart';

class MockJwksClient extends Mock implements JwksClient {}

class MockUserApiKeyRepository extends Mock implements IUserApiKeyRepository {}

/// Encodes [username] and [password] as a Basic auth header value.
String _basicAuth(String username, String password) {
  final encoded = base64.encode(utf8.encode('$username:$password'));
  return 'Basic $encoded';
}

/// A no-op handler that echoes 200 if it receives a request.
final _okHandler = (Request req) => Response.ok('ok');

void main() {
  late MockJwksClient mockJwksClient;
  late Middleware middleware;

  const auth0Domain = 'test.auth0.com';
  const audience = 'https://shedbooks.com';

  setUp(() {
    mockJwksClient = MockJwksClient();
    middleware = cardDavAuthMiddleware(
      auth0Domain: auth0Domain,
      audience: audience,
      jwksClient: mockJwksClient,
    );
  });

  group('cardDavAuthMiddleware token extraction', () {
    test('returns 401 when Authorization header is absent', () async {
      final handler = middleware(_okHandler);
      final req = Request('GET', Uri.parse('http://localhost/carddav/members'));
      final res = await handler(req);

      expect(res.statusCode, equals(401));
    });

    test('returns 401 with correct WWW-Authenticate header when no auth',
        () async {
      final handler = middleware(_okHandler);
      final req = Request('GET', Uri.parse('http://localhost/carddav/members'));
      final res = await handler(req);

      final wwwAuth = res.headers['www-authenticate'] ?? '';
      expect(wwwAuth, contains('Basic'));
      expect(wwwAuth, contains('Bearer'));
    });

    test('returns 401 when Authorization header is not Bearer or Basic',
        () async {
      final handler = middleware(_okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Digest nonce=xyz'},
      );
      final res = await handler(req);
      expect(res.statusCode, equals(401));
    });

    test('returns 401 when Bearer token is malformed (not a JWT)', () async {
      final handler = middleware(_okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Bearer not.a.real.jwt'},
      );
      final res = await handler(req);
      expect(res.statusCode, equals(401));
    });

    test('returns 401 when Basic auth password is empty', () async {
      final handler = middleware(_okHandler);
      // username:  (no password)
      final encoded = base64.encode(utf8.encode('user:'));
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Basic $encoded'},
      );
      final res = await handler(req);
      expect(res.statusCode, equals(401));
    });

    test('returns 401 when Basic auth payload has no colon separator',
        () async {
      final handler = middleware(_okHandler);
      final encoded = base64.encode(utf8.encode('userwithoutseparator'));
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Basic $encoded'},
      );
      final res = await handler(req);
      expect(res.statusCode, equals(401));
    });

    test('returns 401 when Basic auth base64 is not valid base64', () async {
      final handler = middleware(_okHandler);
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Basic !!!not-base64!!!'},
      );
      final res = await handler(req);
      expect(res.statusCode, equals(401));
    });

    test(
        'extracts token from Basic auth — same JWT string used as password '
        'is forwarded for verification', () async {
      final handler = middleware(_okHandler);
      // Provide a syntactically-valid-looking JWT (header.payload.sig) so the
      // middleware advances past token extraction to the JWT verification step.
      // The token below has a decodable header with kid="test-kid".
      final header =
          base64Url.encode(utf8.encode('{"alg":"RS256","kid":"test-kid"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"1"}'));
      const sig = 'fakesig';
      final fakeJwt = '$header.$payload.$sig';

      // The middleware will call getPublicKey("test-kid") once it extracts the
      // token; we let it throw to confirm extraction did occur.
      when(() => mockJwksClient.getPublicKey('test-kid'))
          .thenThrow(Exception('no such key'));

      // Bearer
      final bearerReq = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Bearer $fakeJwt'},
      );
      final bearerRes = await handler(bearerReq);
      // 401 expected (JWT verification fails), but the key lookup was attempted
      expect(bearerRes.statusCode, equals(401));
      verify(() => mockJwksClient.getPublicKey('test-kid')).called(1);

      // Basic — same JWT as password
      final basicReq = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': _basicAuth('ignored-username', fakeJwt)},
      );
      final basicRes = await handler(basicReq);
      expect(basicRes.statusCode, equals(401));
      verify(() => mockJwksClient.getPublicKey('test-kid')).called(1);
    });

    test('returns 401 when JWT header is missing kid claim', () async {
      final handler = middleware(_okHandler);
      // JWT with no kid in header
      final header =
          base64Url.encode(utf8.encode('{"alg":"RS256"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"1"}'));
      final fakeJwt = '$header.$payload.fakesig';

      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': 'Bearer $fakeJwt'},
      );
      final res = await handler(req);

      expect(res.statusCode, equals(401));
      verifyNever(() => mockJwksClient.getPublicKey(any()));
    });
  });

  group('cardDavAuthMiddleware API key auth', () {
    const tEntityId = 'org_entity1';
    const tUserId = 'auth0|user1';
    const tUserEmail = 'user@example.com';
    const tRawKey = '11111111-2222-3333-4444-555555555555';

    late MockUserApiKeyRepository mockRepo;
    late Middleware middlewareWithRepo;

    final tStoredKey = UserApiKey(
      id: '00000000-0000-0000-0000-000000000001',
      entityId: tEntityId,
      userId: tUserId,
      userEmail: tUserEmail,
      apiKeyHash: sha256Hex(tRawKey),
      createdAt: DateTime.utc(2026, 1, 1),
    );

    setUp(() {
      mockRepo = MockUserApiKeyRepository();
      middlewareWithRepo = cardDavAuthMiddleware(
        auth0Domain: auth0Domain,
        audience: audience,
        jwksClient: mockJwksClient,
        apiKeyRepository: mockRepo,
      );
    });

    test(
        'valid credentials — passes through and injects entity_id, sub, email '
        'into auth.claims', () async {
      // Arrange
      when(() => mockRepo.findByApiKeyHash(sha256Hex(tRawKey)))
          .thenAnswer((_) async => tStoredKey);

      Map<String, dynamic>? capturedClaims;
      final capturingHandler = (Request req) {
        capturedClaims =
            req.context['auth.claims'] as Map<String, dynamic>?;
        return Response.ok('ok');
      };
      final handler = middlewareWithRepo(capturingHandler);

      // Act
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': _basicAuth(tUserEmail, tRawKey)},
      );
      final res = await handler(req);

      // Assert
      expect(res.statusCode, equals(200));
      expect(capturedClaims, isNotNull);
      expect(capturedClaims!['https://shedbooks.com/entity_id'], equals(tEntityId));
      expect(capturedClaims!['sub'], equals(tUserId));
      expect(capturedClaims!['email'], equals(tUserEmail));
    });

    test('unknown key (repo returns null) → 401', () async {
      // Arrange
      when(() => mockRepo.findByApiKeyHash(any()))
          .thenAnswer((_) async => null);
      final handler = middlewareWithRepo(_okHandler);

      // Act
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': _basicAuth(tUserEmail, tRawKey)},
      );
      final res = await handler(req);

      // Assert
      expect(res.statusCode, equals(401));
    });

    test('username does not match stored email → 401', () async {
      // Arrange
      when(() => mockRepo.findByApiKeyHash(sha256Hex(tRawKey)))
          .thenAnswer((_) async => tStoredKey);
      final handler = middlewareWithRepo(_okHandler);

      // Act — correct key but wrong username
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {
          'authorization': _basicAuth('other@example.com', tRawKey),
        },
      );
      final res = await handler(req);

      // Assert
      expect(res.statusCode, equals(401));
    });

    test(
        'UUID password is not mistaken for a JWT — API key path is taken',
        () async {
      // A UUID has no dots, so _looksLikeJwt returns false and the API key
      // branch runs (even though the key is unknown).
      when(() => mockRepo.findByApiKeyHash(any()))
          .thenAnswer((_) async => null);
      final handler = middlewareWithRepo(_okHandler);

      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': _basicAuth(tUserEmail, tRawKey)},
      );
      await handler(req);

      // JWT public key lookup must NOT have been attempted.
      verifyNever(() => mockJwksClient.getPublicKey(any()));
      // The repo lookup WAS attempted (confirming the API key branch ran).
      verify(() => mockRepo.findByApiKeyHash(any())).called(1);
    });

    test('no apiKeyRepository provided — non-JWT Basic auth returns 401',
        () async {
      // middlewareWithRepo has a repo; the middleware WITHOUT a repo should
      // not attempt an API key lookup and instead return 401 immediately.
      final handler = middleware(_okHandler); // middleware has no repo
      final req = Request(
        'GET',
        Uri.parse('http://localhost/carddav/members'),
        headers: {'authorization': _basicAuth(tUserEmail, tRawKey)},
      );
      final res = await handler(req);

      expect(res.statusCode, equals(401));
    });
  });
}
