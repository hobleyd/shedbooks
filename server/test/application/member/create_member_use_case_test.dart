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

import 'package:shedbooks_server/application/member/create_member_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

void main() {
  late MockMemberRepository repository;
  late CreateMemberUseCase sut;

  const tEntityId = 'entity-1';
  final tDateJoined = DateTime.utc(2021, 2, 13);
  final tDob = DateTime.utc(1945, 6, 1);

  final tMember = Member(
    id: '00000000-0000-0000-0000-000000000001',
    entityId: tEntityId,
    firstName: 'Ron',
    lastName: 'Anderson',
    dateJoined: tDateJoined,
    membershipStatus: '2026',
    streetAddress: '6 Curlew St Woodgate',
    poBox: '560 WG',
    email: 'ron@example.com',
    phone: '0429879483',
    dateOfBirth: tDob,
    emergencyContact: 'Fay',
    etag: 'etag-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockMemberRepository();
    sut = CreateMemberUseCase(repository);
    registerFallbackValue(tDateJoined);
    when(
      () => repository.create(
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
        emergencyContact: any(named: 'emergencyContact'),
      ),
    ).thenAnswer((_) async => tMember);
  });

  group('CreateMemberUseCase', () {
    test('creates a member with all fields and returns the entity', () async {
      final result = await sut.execute(
        entityId: tEntityId,
        firstName: 'Ron',
        lastName: 'Anderson',
        dateJoined: tDateJoined,
        membershipStatus: '2026',
        streetAddress: '6 Curlew St Woodgate',
        poBox: '560 WG',
        email: 'ron@example.com',
        phone: '0429879483',
        dateOfBirth: tDob,
        emergencyContact: 'Fay',
      );

      expect(result, equals(tMember));
      verify(
        () => repository.create(
          entityId: tEntityId,
          firstName: 'Ron',
          lastName: 'Anderson',
          dateJoined: tDateJoined,
          membershipStatus: '2026',
          streetAddress: '6 Curlew St Woodgate',
          poBox: '560 WG',
          email: 'ron@example.com',
          phone: '0429879483',
          dateOfBirth: tDob,
          emergencyContact: 'Fay',
        ),
      ).called(1);
    });

    test('trims leading/trailing whitespace from names before persisting',
        () async {
      await sut.execute(
          entityId: tEntityId, firstName: '  Ron  ', lastName: '  Anderson  ');

      verify(
        () => repository.create(
          entityId: tEntityId,
          firstName: 'Ron',
          lastName: 'Anderson',
          dateJoined: any(named: 'dateJoined'),
          membershipStatus: any(named: 'membershipStatus'),
          streetAddress: any(named: 'streetAddress'),
          poBox: any(named: 'poBox'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          dateOfBirth: any(named: 'dateOfBirth'),
          emergencyContact: any(named: 'emergencyContact'),
        ),
      ).called(1);
    });

    test('converts blank optional strings to null before persisting', () async {
      await sut.execute(
        entityId: tEntityId,
        firstName: '',
        lastName: 'Anderson',
        membershipStatus: '   ',
        streetAddress: '',
        email: '  ',
        emergencyContact: '',
      );

      verify(
        () => repository.create(
          entityId: tEntityId,
          firstName: '',
          lastName: 'Anderson',
          dateJoined: any(named: 'dateJoined'),
          membershipStatus: null,
          streetAddress: null,
          poBox: any(named: 'poBox'),
          email: null,
          phone: any(named: 'phone'),
          dateOfBirth: any(named: 'dateOfBirth'),
          emergencyContact: null,
        ),
      ).called(1);
    });

    test('throws MemberValidationException when lastName is empty', () async {
      expect(
        () => sut.execute(entityId: tEntityId, firstName: 'Ron', lastName: ''),
        throwsA(isA<MemberValidationException>()),
      );
      verifyNever(
        () => repository.create(
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
          emergencyContact: any(named: 'emergencyContact'),
        ),
      );
    });

    test('throws MemberValidationException when lastName is only whitespace',
        () async {
      expect(
        () => sut.execute(
            entityId: tEntityId, firstName: 'Ron', lastName: '   '),
        throwsA(isA<MemberValidationException>()),
      );
    });

    test('accepts FLM as a valid membership status', () async {
      await sut.execute(
          entityId: tEntityId,
          firstName: '',
          lastName: 'Member',
          membershipStatus: 'FLM');

      verify(
        () => repository.create(
          entityId: tEntityId,
          firstName: '',
          lastName: 'Member',
          membershipStatus: 'FLM',
          dateJoined: any(named: 'dateJoined'),
          streetAddress: any(named: 'streetAddress'),
          poBox: any(named: 'poBox'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          dateOfBirth: any(named: 'dateOfBirth'),
          emergencyContact: any(named: 'emergencyContact'),
        ),
      ).called(1);
    });

    test('accepts year string as a valid membership status', () async {
      await sut.execute(
          entityId: tEntityId,
          firstName: '',
          lastName: 'Member',
          membershipStatus: '2026');

      verify(
        () => repository.create(
          entityId: tEntityId,
          firstName: '',
          lastName: 'Member',
          membershipStatus: '2026',
          dateJoined: any(named: 'dateJoined'),
          streetAddress: any(named: 'streetAddress'),
          poBox: any(named: 'poBox'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          dateOfBirth: any(named: 'dateOfBirth'),
          emergencyContact: any(named: 'emergencyContact'),
        ),
      ).called(1);
    });
  });
}
