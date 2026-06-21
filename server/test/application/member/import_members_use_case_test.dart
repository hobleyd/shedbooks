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
import 'package:test/test.dart';

import 'package:shedbooks_server/application/member/import_members_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

void main() {
  late MockMemberRepository repository;
  late ImportMembersUseCase sut;

  const tEntityId = 'entity-1';

  final tImportData = [
    MemberImportData(
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
    ),
    MemberImportData(
      firstName: 'Lynn',
      lastName: 'Bartlett',
      membershipStatus: 'FLM',
    ),
  ];

  final tCreated = [
    Member(
      id: '00000000-0000-0000-0000-000000000001',
      entityId: tEntityId,
      firstName: 'Ron',
      lastName: 'Anderson',
      membershipStatus: '2026',
      etag: 'etag-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    Member(
      id: '00000000-0000-0000-0000-000000000002',
      entityId: tEntityId,
      firstName: 'Lynn',
      lastName: 'Bartlett',
      membershipStatus: 'FLM',
      etag: 'etag-2',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  setUp(() {
    repository = MockMemberRepository();
    sut = ImportMembersUseCase(repository);
    when(() => repository.importMany(
          entityId: any(named: 'entityId'),
          members: any(named: 'members'),
        )).thenAnswer((_) async => tCreated);
  });

  group('ImportMembersUseCase', () {
    test('imports a list of valid members and returns created entities',
        () async {
      final result =
          await sut.execute(entityId: tEntityId, members: tImportData);

      expect(result, equals(tCreated));
      verify(() => repository.importMany(
            entityId: tEntityId,
            members: any(named: 'members'),
          )).called(1);
    });

    test('returns empty list when given empty input', () async {
      final result = await sut.execute(entityId: tEntityId, members: []);

      expect(result, isEmpty);
      verifyNever(() => repository.importMany(
            entityId: any(named: 'entityId'),
            members: any(named: 'members'),
          ));
    });

    test(
        'throws MemberValidationException when any member has an empty lastName',
        () async {
      final invalid = [
        MemberImportData(firstName: 'Valid', lastName: 'Name'),
        MemberImportData(firstName: 'No', lastName: ''),
      ];

      expect(
        () => sut.execute(entityId: tEntityId, members: invalid),
        throwsA(isA<MemberValidationException>()),
      );
      verifyNever(() => repository.importMany(
            entityId: any(named: 'entityId'),
            members: any(named: 'members'),
          ));
    });

    test('trims names and converts blank optional fields to null', () async {
      final input = [
        MemberImportData(
          firstName: '  Ron  ',
          lastName: '  Anderson  ',
          membershipStatus: '  ',
          email: '',
          streetAddress: '   ',
        ),
      ];
      when(() => repository.importMany(
            entityId: tEntityId,
            members: any(named: 'members'),
          )).thenAnswer((_) async => [tCreated.first]);

      await sut.execute(entityId: tEntityId, members: input);

      final captured = verify(() => repository.importMany(
            entityId: tEntityId,
            members: captureAny(named: 'members'),
          )).captured.single as List<MemberImportData>;

      expect(captured.first.firstName, equals('Ron'));
      expect(captured.first.lastName, equals('Anderson'));
      expect(captured.first.membershipStatus, isNull);
      expect(captured.first.email, isNull);
      expect(captured.first.streetAddress, isNull);
    });

    test('preserves FLM and year statuses verbatim', () async {
      final input = [
        MemberImportData(firstName: '', lastName: 'LifeMember', membershipStatus: 'FLM'),
        MemberImportData(firstName: '', lastName: 'CurrentMember', membershipStatus: '2026'),
        MemberImportData(firstName: '', lastName: 'GuestMember', membershipStatus: 'Guest'),
      ];
      when(() => repository.importMany(
            entityId: tEntityId,
            members: any(named: 'members'),
          )).thenAnswer((_) async => tCreated);

      await sut.execute(entityId: tEntityId, members: input);

      final captured = verify(() => repository.importMany(
            entityId: tEntityId,
            members: captureAny(named: 'members'),
          )).captured.single as List<MemberImportData>;

      expect(captured[0].membershipStatus, equals('FLM'));
      expect(captured[1].membershipStatus, equals('2026'));
      expect(captured[2].membershipStatus, equals('Guest'));
    });
  });
}
