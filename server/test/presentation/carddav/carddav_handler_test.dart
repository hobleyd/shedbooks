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

import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/member/create_member_use_case.dart';
import 'package:shedbooks_server/application/member/delete_member_use_case.dart';
import 'package:shedbooks_server/application/member/get_member_use_case.dart';
import 'package:shedbooks_server/application/member/list_members_use_case.dart';
import 'package:shedbooks_server/application/member/update_member_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/presentation/handlers/carddav_handler.dart';

class MockListMembersUseCase extends Mock implements ListMembersUseCase {}

class MockGetMemberUseCase extends Mock implements GetMemberUseCase {}

class MockCreateMemberUseCase extends Mock implements CreateMemberUseCase {}

class MockUpdateMemberUseCase extends Mock implements UpdateMemberUseCase {}

class MockDeleteMemberUseCase extends Mock implements DeleteMemberUseCase {}

/// Returns a [Request] with [auth.claims] pre-populated (simulating a
/// successfully authenticated request that has passed the auth middleware).
Request _authed(
  String method,
  String path, {
  String body = '',
  Map<String, String> headers = const {},
  String entityId = 'entity-1',
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body,
    headers: headers,
    context: {
      'auth.claims': {'https://shedbooks.com/entity_id': entityId},
    },
  );
}

/// Returns a [Request] with no auth context (simulating a missing/invalid token).
Request _unauthed(String method, String path) {
  return Request(method, Uri.parse('http://localhost$path'));
}

void main() {
  late MockListMembersUseCase mockList;
  late MockGetMemberUseCase mockGet;
  late MockCreateMemberUseCase mockCreate;
  late MockUpdateMemberUseCase mockUpdate;
  late MockDeleteMemberUseCase mockDelete;
  late CardDavHandler sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000001';

  final tMember = Member(
    id: tId,
    entityId: tEntityId,
    firstName: 'Ron',
    lastName: 'Anderson',
    dateJoined: DateTime.utc(2021, 2, 13),
    membershipStatus: '2026',
    streetAddress: '6 Curlew St Woodgate',
    poBox: '560 WG',
    email: 'ron@example.com',
    phone: '0429879483',
    dateOfBirth: DateTime.utc(1945, 6, 1),
    emergencyContactName: 'Fay',
    woodworkingInduction: DateTime.utc(2022, 3, 5),
    metalworkingInduction: DateTime.utc(2022, 4, 10),
    gymWaiver: DateTime.utc(2022, 5, 20),
    etag: 'etag-abc',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 6, 15),
  );

  setUp(() {
    mockList = MockListMembersUseCase();
    mockGet = MockGetMemberUseCase();
    mockCreate = MockCreateMemberUseCase();
    mockUpdate = MockUpdateMemberUseCase();
    mockDelete = MockDeleteMemberUseCase();

    sut = CardDavHandler(
      list: mockList,
      get: mockGet,
      create: mockCreate,
      update: mockUpdate,
      delete: mockDelete,
    );

    registerFallbackValue(DateTime.utc(2026));
  });

  // ── OPTIONS ────────────────────────────────────────────────────────────────

  group('handleOptions', () {
    test('returns 200 with DAV and Allow headers', () async {
      final req = _authed('OPTIONS', '/carddav/members');
      final res = await sut.handleOptions(req);

      expect(res.statusCode, equals(200));
      expect(res.headers['dav'], contains('addressbook'));
      expect(res.headers['allow'], contains('PROPFIND'));
    });

    test('returns 200 even without auth claims', () async {
      final req = _unauthed('OPTIONS', '/carddav/members');
      final res = await sut.handleOptions(req);
      expect(res.statusCode, equals(200));
    });
  });

  // ── PROPFIND ───────────────────────────────────────────────────────────────

  group('handlePropfind', () {
    test('returns 207 multi-status with member entries', () async {
      when(() => mockList.execute(entityId: tEntityId))
          .thenAnswer((_) async => [tMember]);

      final req = _authed('PROPFIND', '/carddav/members');
      final res = await sut.handlePropfind(req);

      expect(res.statusCode, equals(207));
      final body = await res.readAsString();
      expect(body, contains('<D:multistatus'));
      expect(body, contains('$tId.vcf'));
      expect(body, contains('"etag-abc"'));
      expect(body, contains('text/vcard'));
    });

    test('includes collection resource type for the addressbook itself',
        () async {
      when(() => mockList.execute(entityId: tEntityId))
          .thenAnswer((_) async => []);

      final req = _authed('PROPFIND', '/carddav/members');
      final res = await sut.handlePropfind(req);
      final body = await res.readAsString();

      expect(body, contains('<C:addressbook/>'));
      expect(body, contains('<D:displayname>Members</D:displayname>'));
      expect(body, contains('<C:addressbook-home-set>'));
      expect(body, contains('<D:current-user-principal>'));
    });

    test('returns 207 with empty children when no members exist', () async {
      when(() => mockList.execute(entityId: tEntityId))
          .thenAnswer((_) async => []);

      final req = _authed('PROPFIND', '/carddav/members');
      final res = await sut.handlePropfind(req);

      expect(res.statusCode, equals(207));
      final body = await res.readAsString();
      // Only the collection response entry, no member entries
      expect(body, contains('/carddav/members/'));
      expect(body, isNot(contains('.vcf')));
    });

    test('returns 401 when auth claims are absent', () async {
      final req = _unauthed('PROPFIND', '/carddav/members');
      final res = await sut.handlePropfind(req);
      expect(res.statusCode, equals(401));
    });
  });

  // ── GET ────────────────────────────────────────────────────────────────────

  group('handleGet', () {
    test('returns 200 with vCard content and ETag header', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');

      expect(res.statusCode, equals(200));
      expect(res.headers['content-type'], contains('text/vcard'));
      expect(res.headers['etag'], equals('"etag-abc"'));
    });

    test('vCard contains BEGIN:VCARD, FN, N, UID, VERSION and END:VCARD',
        () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      final body = await res.readAsString();

      expect(body, contains('BEGIN:VCARD'));
      expect(body, contains('VERSION:3.0'));
      expect(body, contains('UID:$tId'));
      // FN uses displayName: "firstName lastName"
      expect(body, contains('FN:Ron Anderson'));
      // N uses "lastName;firstName;;;"
      expect(body, contains('N:Anderson;Ron;;;'));
      expect(body, contains('END:VCARD'));
    });

    test('vCard encodes email, phone, membership status and date-joined',
        () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      final body = await res.readAsString();

      expect(body, contains('EMAIL;TYPE=INTERNET:ron@example.com'));
      expect(body, contains('TEL;TYPE=CELL:0429879483'));
      expect(body, contains('X-MEMBERSHIP-STATUS:2026'));
      expect(body, contains('X-DATE-JOINED:20210213'));
    });

    test('vCard encodes ADR with poBox in position 0 and street in position 2',
        () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      final body = await res.readAsString();

      // ADR format: PO Box;;Street;City;Region;PostCode;Country
      expect(body, contains('ADR;TYPE=HOME:560 WG;;6 Curlew St Woodgate;;;;'));
    });

    test('vCard encodes date-of-birth and emergency contact', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      final body = await res.readAsString();

      expect(body, contains('BDAY:19450601'));
      expect(body, contains('X-EMERGENCY-CONTACT-NAME:Fay'));
    });

    test('strips .vcf suffix when looking up by ID', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');

      expect(res.statusCode, equals(200));
      verify(() => mockGet.execute(tId, entityId: tEntityId)).called(1);
    });

    test('returns 404 when member is not found', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenThrow(MemberNotFoundException(tId));

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');

      expect(res.statusCode, equals(404));
    });

    test('returns 401 when auth claims are absent', () async {
      final req = _unauthed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      expect(res.statusCode, equals(401));
    });

    test('omits optional fields when they are null', () async {
      final minimalMember = Member(
        id: tId,
        entityId: tEntityId,
        firstName: 'Minimal',
        lastName: 'Member',
        etag: 'etag-min',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => minimalMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      final body = await res.readAsString();

      expect(body, isNot(contains('EMAIL')));
      expect(body, isNot(contains('TEL')));
      expect(body, isNot(contains('ADR')));
      expect(body, isNot(contains('BDAY')));
      expect(body, isNot(contains('X-MEMBERSHIP-STATUS')));
      expect(body, isNot(contains('X-DATE-JOINED')));
      expect(body, isNot(contains('X-EMERGENCY-CONTACT-NAME')));
      expect(body, isNot(contains('X-EMERGENCY-CONTACT-PHONE')));
      expect(body, isNot(contains('X-WOODWORKING-INDUCTION')));
      expect(body, isNot(contains('X-METALWORKING-INDUCTION')));
      expect(body, isNot(contains('X-GYM-WAIVER')));
    });

    test('vCard encodes induction and waiver dates', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      final req = _authed('GET', '/carddav/members/$tId.vcf');
      final res = await sut.handleGet(req, '$tId.vcf');
      final body = await res.readAsString();

      expect(body, contains('X-WOODWORKING-INDUCTION:20220305'));
      expect(body, contains('X-METALWORKING-INDUCTION:20220410'));
      expect(body, contains('X-GYM-WAIVER:20220520'));
    });
  });

  // ── PUT ────────────────────────────────────────────────────────────────────

  group('handlePut', () {
    // N field: "LastName;FirstName;;;"
    const tVCard = '''BEGIN:VCARD
VERSION:3.0
UID:$tId
FN:Ron Anderson
N:Anderson;Ron;;;
EMAIL;TYPE=INTERNET:ron@example.com
TEL;TYPE=CELL:0429879483
ADR;TYPE=HOME:560 WG;;6 Curlew St Woodgate;;;;
BDAY:19450601
X-DATE-JOINED:20210213
X-MEMBERSHIP-STATUS:2026
X-EMERGENCY-CONTACT-NAME:Fay
X-WOODWORKING-INDUCTION:20220305
X-METALWORKING-INDUCTION:20220410
X-GYM-WAIVER:20220520
END:VCARD''';

    test('updates existing member and returns 200 with ETag', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);
      when(() => mockUpdate.execute(
            id: tId,
            entityId: tEntityId,
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            dateJoined: any(named: 'dateJoined'),
            membershipStatus: any(named: 'membershipStatus'),
            streetAddress: any(named: 'streetAddress'),
            poBox: any(named: 'poBox'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            dateOfBirth: any(named: 'dateOfBirth'),
            emergencyContactName: any(named: 'emergencyContactName'),
            emergencyContactPhone: any(named: 'emergencyContactPhone'),
            woodworkingInduction: any(named: 'woodworkingInduction'),
            metalworkingInduction: any(named: 'metalworkingInduction'),
            gymWaiver: any(named: 'gymWaiver'),
          )).thenAnswer((_) async => tMember);

      final req = _authed('PUT', '/carddav/members/$tId.vcf', body: tVCard);
      final res = await sut.handlePut(req, '$tId.vcf');

      expect(res.statusCode, equals(200));
      expect(res.headers['etag'], equals('"etag-abc"'));
    });

    test('parses vCard N field correctly on update', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);
      when(() => mockUpdate.execute(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            dateJoined: any(named: 'dateJoined'),
            membershipStatus: any(named: 'membershipStatus'),
            streetAddress: any(named: 'streetAddress'),
            poBox: any(named: 'poBox'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            dateOfBirth: any(named: 'dateOfBirth'),
            emergencyContactName: any(named: 'emergencyContactName'),
            emergencyContactPhone: any(named: 'emergencyContactPhone'),
            woodworkingInduction: any(named: 'woodworkingInduction'),
            metalworkingInduction: any(named: 'metalworkingInduction'),
            gymWaiver: any(named: 'gymWaiver'),
          )).thenAnswer((_) async => tMember);

      final req = _authed('PUT', '/carddav/members/$tId.vcf', body: tVCard);
      await sut.handlePut(req, '$tId.vcf');

      final captured = verify(() => mockUpdate.execute(
            id: tId,
            entityId: tEntityId,
            firstName: captureAny(named: 'firstName'),
            lastName: captureAny(named: 'lastName'),
            dateJoined: captureAny(named: 'dateJoined'),
            membershipStatus: captureAny(named: 'membershipStatus'),
            streetAddress: captureAny(named: 'streetAddress'),
            poBox: captureAny(named: 'poBox'),
            email: captureAny(named: 'email'),
            phone: captureAny(named: 'phone'),
            dateOfBirth: captureAny(named: 'dateOfBirth'),
            emergencyContactName: captureAny(named: 'emergencyContactName'),
            emergencyContactPhone: captureAny(named: 'emergencyContactPhone'),
            woodworkingInduction: captureAny(named: 'woodworkingInduction'),
            metalworkingInduction: captureAny(named: 'metalworkingInduction'),
            gymWaiver: captureAny(named: 'gymWaiver'),
          )).captured;

      // captured order follows the captureAny declaration order above
      expect(captured[0], equals('Ron'));                         // firstName
      expect(captured[1], equals('Anderson'));                    // lastName
      expect(captured[2], equals(DateTime.utc(2021, 2, 13)));    // dateJoined
      expect(captured[3], equals('2026'));                        // membershipStatus
      expect(captured[4], equals('6 Curlew St Woodgate'));        // streetAddress
      expect(captured[5], equals('560 WG'));                      // poBox
      expect(captured[6], equals('ron@example.com'));             // email
      expect(captured[7], equals('0429879483'));                  // phone
      expect(captured[8], equals(DateTime.utc(1945, 6, 1)));     // dateOfBirth
      expect(captured[9], equals('Fay'));                         // emergencyContactName
      expect(captured[10], isNull);                               // emergencyContactPhone
      expect(captured[11], equals(DateTime.utc(2022, 3, 5)));    // woodworkingInduction
      expect(captured[12], equals(DateTime.utc(2022, 4, 10)));   // metalworkingInduction
      expect(captured[13], equals(DateTime.utc(2022, 5, 20)));   // gymWaiver
    });

    test('creates member when not found and returns 201', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenThrow(MemberNotFoundException(tId));
      when(() => mockCreate.execute(
            entityId: any(named: 'entityId'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            dateJoined: any(named: 'dateJoined'),
            membershipStatus: any(named: 'membershipStatus'),
            streetAddress: any(named: 'streetAddress'),
            poBox: any(named: 'poBox'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            dateOfBirth: any(named: 'dateOfBirth'),
            emergencyContactName: any(named: 'emergencyContactName'),
            emergencyContactPhone: any(named: 'emergencyContactPhone'),
            woodworkingInduction: any(named: 'woodworkingInduction'),
            metalworkingInduction: any(named: 'metalworkingInduction'),
            gymWaiver: any(named: 'gymWaiver'),
          )).thenAnswer((_) async => tMember);

      final req = _authed('PUT', '/carddav/members/$tId.vcf', body: tVCard);
      final res = await sut.handlePut(req, '$tId.vcf');

      expect(res.statusCode, equals(201));
      expect(res.headers['etag'], equals('"etag-abc"'));
    });

    test('treats non-UUID uid as not-found and falls through to create',
        () async {
      const nonUuidUid = 'not-a-valid-uuid';
      const vcard = '''BEGIN:VCARD
VERSION:3.0
N:Member;New;;;
FN:New Member
END:VCARD''';

      when(() => mockCreate.execute(
            entityId: any(named: 'entityId'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            dateJoined: any(named: 'dateJoined'),
            membershipStatus: any(named: 'membershipStatus'),
            streetAddress: any(named: 'streetAddress'),
            poBox: any(named: 'poBox'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            dateOfBirth: any(named: 'dateOfBirth'),
            emergencyContactName: any(named: 'emergencyContactName'),
            emergencyContactPhone: any(named: 'emergencyContactPhone'),
            woodworkingInduction: any(named: 'woodworkingInduction'),
            metalworkingInduction: any(named: 'metalworkingInduction'),
            gymWaiver: any(named: 'gymWaiver'),
          )).thenAnswer((_) async => tMember);

      final req = _authed('PUT', '/carddav/members/$nonUuidUid', body: vcard);
      final res = await sut.handlePut(req, nonUuidUid);

      expect(res.statusCode, equals(201));
      verifyNever(() => mockGet.execute(any(), entityId: any(named: 'entityId')));
    });

    test('returns 400 when N field last name is empty', () async {
      const missingLastName = '''BEGIN:VCARD
VERSION:3.0
N:;FirstNameOnly;;;
FN:FirstNameOnly
END:VCARD''';

      final req =
          _authed('PUT', '/carddav/members/$tId.vcf', body: missingLastName);
      final res = await sut.handlePut(req, '$tId.vcf');

      expect(res.statusCode, equals(400));
    });

    test('returns 401 when auth claims are absent', () async {
      final req = _unauthed('PUT', '/carddav/members/$tId.vcf');
      final res = await sut.handlePut(req, '$tId.vcf');
      expect(res.statusCode, equals(401));
    });

    test('vCard round-trip preserves all fields through GET then PUT', () async {
      // Set up GET to return the full member
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);
      when(() => mockUpdate.execute(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            dateJoined: any(named: 'dateJoined'),
            membershipStatus: any(named: 'membershipStatus'),
            streetAddress: any(named: 'streetAddress'),
            poBox: any(named: 'poBox'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
            dateOfBirth: any(named: 'dateOfBirth'),
            emergencyContactName: any(named: 'emergencyContactName'),
            emergencyContactPhone: any(named: 'emergencyContactPhone'),
            woodworkingInduction: any(named: 'woodworkingInduction'),
            metalworkingInduction: any(named: 'metalworkingInduction'),
            gymWaiver: any(named: 'gymWaiver'),
          )).thenAnswer((_) async => tMember);

      // GET the vCard
      final getReq = _authed('GET', '/carddav/members/$tId.vcf');
      final getRes = await sut.handleGet(getReq, '$tId.vcf');
      final vcard = await getRes.readAsString();

      // Reset the GET mock so it still returns on the second call in handlePut
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);

      // PUT the same vCard back
      final putReq =
          _authed('PUT', '/carddav/members/$tId.vcf', body: vcard);
      await sut.handlePut(putReq, '$tId.vcf');

      final captured = verify(() => mockUpdate.execute(
            id: tId,
            entityId: tEntityId,
            firstName: captureAny(named: 'firstName'),
            lastName: captureAny(named: 'lastName'),
            dateJoined: captureAny(named: 'dateJoined'),
            membershipStatus: captureAny(named: 'membershipStatus'),
            streetAddress: captureAny(named: 'streetAddress'),
            poBox: captureAny(named: 'poBox'),
            email: captureAny(named: 'email'),
            phone: captureAny(named: 'phone'),
            dateOfBirth: captureAny(named: 'dateOfBirth'),
            emergencyContactName: captureAny(named: 'emergencyContactName'),
            emergencyContactPhone: captureAny(named: 'emergencyContactPhone'),
            woodworkingInduction: captureAny(named: 'woodworkingInduction'),
            metalworkingInduction: captureAny(named: 'metalworkingInduction'),
            gymWaiver: captureAny(named: 'gymWaiver'),
          )).captured;

      expect(captured[0], equals(tMember.firstName));
      expect(captured[1], equals(tMember.lastName));
      expect(captured[2], equals(tMember.dateJoined));
      expect(captured[3], equals(tMember.membershipStatus));
      expect(captured[4], equals(tMember.streetAddress));
      expect(captured[5], equals(tMember.poBox));
      expect(captured[6], equals(tMember.email));
      expect(captured[7], equals(tMember.phone));
      expect(captured[8], equals(tMember.dateOfBirth));
      expect(captured[9], equals(tMember.emergencyContactName));
      expect(captured[10], equals(tMember.emergencyContactPhone));
      expect(captured[11], equals(tMember.woodworkingInduction));
      expect(captured[12], equals(tMember.metalworkingInduction));
      expect(captured[13], equals(tMember.gymWaiver));
    });
  });

  // ── DELETE ─────────────────────────────────────────────────────────────────

  group('handleDelete', () {
    test('returns 204 on successful soft-delete', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);
      when(() => mockDelete.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async {});

      final req = _authed('DELETE', '/carddav/members/$tId.vcf');
      final res = await sut.handleDelete(req, '$tId.vcf');

      expect(res.statusCode, equals(204));
      verify(() => mockDelete.execute(tId, entityId: tEntityId)).called(1);
    });

    test('returns 404 when member does not exist', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);
      when(() => mockDelete.execute(tId, entityId: tEntityId))
          .thenThrow(MemberNotFoundException(tId));

      final req = _authed('DELETE', '/carddav/members/$tId.vcf');
      final res = await sut.handleDelete(req, '$tId.vcf');

      expect(res.statusCode, equals(404));
    });

    test('returns 401 when auth claims are absent', () async {
      final req = _unauthed('DELETE', '/carddav/members/$tId.vcf');
      final res = await sut.handleDelete(req, '$tId.vcf');
      expect(res.statusCode, equals(401));
    });

    test('strips .vcf suffix when looking up by ID', () async {
      when(() => mockGet.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async => tMember);
      when(() => mockDelete.execute(tId, entityId: tEntityId))
          .thenAnswer((_) async {});

      final req = _authed('DELETE', '/carddav/members/$tId.vcf');
      await sut.handleDelete(req, '$tId.vcf');

      verify(() => mockDelete.execute(tId, entityId: tEntityId)).called(1);
    });
  });
}
