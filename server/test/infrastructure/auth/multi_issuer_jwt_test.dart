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
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/repositories/i_entity_details_repository.dart';
import 'package:shedbooks_server/infrastructure/auth/jwks_client.dart';
import 'package:shedbooks_server/infrastructure/auth/multi_issuer_jwt.dart';

class MockJwksClient extends Mock implements JwksClient {}

class MockEntityDetailsRepository extends Mock
    implements IEntityDetailsRepository {}

/// Builds an unsigned-looking JWT string (header.payload.sig) — enough to
/// exercise header/payload extraction without a real signature, matching
/// this codebase's existing convention (see carddav_auth_middleware_test.dart)
/// of testing the pre-verification extraction/dispatch logic directly,
/// rather than round-tripping a real RS256 signature in unit tests.
String _fakeJwt(Map<String, dynamic> header, Map<String, dynamic> payload) {
  final h = base64Url.encode(utf8.encode(jsonEncode(header)));
  final p = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$h.$p.fakesig';
}

void main() {
  group('peekIssuer', () {
    test('returns the iss claim from a well-formed token', () {
      final token = _fakeJwt(
        {'alg': 'RS256', 'kid': 'k1'},
        {'iss': 'https://example-issuer.test/', 'sub': '1'},
      );
      expect(peekIssuer(token), equals('https://example-issuer.test/'));
    });

    test('returns null when the token has fewer than 3 parts', () {
      expect(peekIssuer('not-a-jwt'), isNull);
      expect(peekIssuer('only.two'), isNull);
    });

    test('returns null when the payload is not valid base64/JSON', () {
      expect(peekIssuer('header.!!!not-valid!!!.sig'), isNull);
    });

    test('returns null when the payload has no iss claim', () {
      final token = _fakeJwt({'alg': 'RS256'}, {'sub': '1'});
      expect(peekIssuer(token), isNull);
    });
  });

  group('resolveEntraEmail', () {
    test('prefers the email claim when present', () {
      final claims = {
        'email': 'alice@example.com',
        'preferred_username': 'alice.upn@example.com',
        'upn': 'alice.other@example.com',
      };
      expect(resolveEntraEmail(claims), equals('alice@example.com'));
    });

    test('falls back to preferred_username when email is absent', () {
      final claims = {
        'preferred_username': 'alice@example.com',
        'upn': 'alice.other@example.com',
      };
      expect(resolveEntraEmail(claims), equals('alice@example.com'));
    });

    test('falls back to preferred_username when email is empty', () {
      final claims = {
        'email': '',
        'preferred_username': 'alice@example.com',
      };
      expect(resolveEntraEmail(claims), equals('alice@example.com'));
    });

    test(
        'falls back to upn when neither email nor preferred_username '
        'are present', () {
      final claims = {'upn': 'alice@example.com'};
      expect(resolveEntraEmail(claims), equals('alice@example.com'));
    });

    test('returns empty string when no email-bearing claim is present', () {
      expect(resolveEntraEmail({'sub': '1'}), equals(''));
    });
  });

  group('normaliseEntraClaims', () {
    // A real token minted for the "Shedbooks Login" app registration in the
    // woodgatemensshed.org.au tenant (captured during the migration, not
    // fabricated) — decoded payload, signature stripped. Exercises the
    // actual claim shape Entra emits rather than an assumed one.
    final realCapturedPayload = <String, dynamic>{
      'aud': 'c925ee79-bc92-4130-956d-7ae19cf5bc8f',
      'iss':
          'https://login.microsoftonline.com/012aa7d6-8356-46f2-b5d2-5d66c9964d47/v2.0',
      'name': 'David Hobley',
      'oid': '177e0e3b-d3f6-44b8-a8d6-dfa840a8af7a',
      'preferred_username': 'david.hobley@woodgatemensshed.org.au',
      'roles': ['administrator'],
      'scp': 'access_as_user',
      'sub': 'sKWApr1W8dUeZUZgmxbIzz5NauH4z1shDslG3aHnPr8',
      'tid': '012aa7d6-8356-46f2-b5d2-5d66c9964d47',
      'ver': '2.0',
    };

    test('maps the real captured payload to the app claim shape', () {
      final result =
          normaliseEntraClaims(realCapturedPayload, 'woodgate-mens-shed');

      expect(result['https://shedbooks.com/entity_id'],
          equals('woodgate-mens-shed'));
      // oid, not the token's own (pairwise, per-app) sub.
      expect(result['sub'], equals('177e0e3b-d3f6-44b8-a8d6-dfa840a8af7a'));
      expect(result['email'], equals('david.hobley@woodgatemensshed.org.au'));
      expect(result['https://shedbooks.com/roles'], equals(['administrator']));
    });

    test('throws when oid is absent', () {
      final claims = Map<String, dynamic>.from(realCapturedPayload)
        ..remove('oid');
      expect(
        () => normaliseEntraClaims(claims, 'woodgate-mens-shed'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when oid is present but not a string', () {
      final claims = Map<String, dynamic>.from(realCapturedPayload)
        ..['oid'] = 12345;
      expect(
        () => normaliseEntraClaims(claims, 'woodgate-mens-shed'),
        throwsA(isA<Exception>()),
      );
    });

    test('defaults roles to an empty list when absent', () {
      final claims = Map<String, dynamic>.from(realCapturedPayload)
        ..remove('roles');
      final result = normaliseEntraClaims(claims, 'woodgate-mens-shed');
      expect(result['https://shedbooks.com/roles'], equals(<dynamic>[]));
    });
  });

  group('EntraJwtVerifier', () {
    late MockJwksClient mockJwksClient;
    late MockEntityDetailsRepository mockRepo;
    late EntraJwtVerifier verifier;

    const tenantId = '012aa7d6-8356-46f2-b5d2-5d66c9964d47';
    const clientId = 'c925ee79-bc92-4130-956d-7ae19cf5bc8f';

    setUp(() {
      mockJwksClient = MockJwksClient();
      mockRepo = MockEntityDetailsRepository();
      verifier = EntraJwtVerifier(
        tenantId: tenantId,
        clientId: clientId,
        jwksClient: mockJwksClient,
        entityDetailsRepository: mockRepo,
      );
    });

    test('issuer is built from the tenant id in v2.0 shape', () {
      expect(
        verifier.issuer,
        equals('https://login.microsoftonline.com/$tenantId/v2.0'),
      );
    });

    test('throws when the JWT header has no kid', () async {
      final token = _fakeJwt({'alg': 'RS256'}, {'sub': '1'});

      expect(() => verifier.call(token), throwsA(isA<Exception>()));
      verifyNever(() => mockJwksClient.getPublicKey(any()));
    });

    test('attempts key lookup with the header kid before failing', () async {
      final token = _fakeJwt(
        {'alg': 'RS256', 'kid': 'entra-kid'},
        {'sub': '1'},
      );
      when(() => mockJwksClient.getPublicKey('entra-kid'))
          .thenThrow(Exception('no such key'));

      await expectLater(verifier.call(token), throwsException);
      verify(() => mockJwksClient.getPublicKey('entra-kid')).called(1);
      // Never got far enough to need the entity lookup.
      verifyNever(
        () => mockRepo.findEntityIdByEntraTenantId(any()),
      );
    });
  });
}
