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

import 'package:shedbooks_server/application/member/update_member_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

void main() {
  late MockMemberRepository repository;
  late UpdateMemberUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tMember = Member(
    id: tId,
    entityId: tEntityId,
    firstName: 'Ron',
    lastName: 'Anderson',
    membershipStatus: '2026',
    etag: 'new-etag',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 6, 20),
  );

  setUp(() {
    repository = MockMemberRepository();
    sut = UpdateMemberUseCase(repository);
    when(
      () => repository.update(
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
      ),
    ).thenAnswer((_) async => tMember);
  });

  group('UpdateMemberUseCase', () {
    test('updates and returns the member', () async {
      final result = await sut.execute(
          id: tId, entityId: tEntityId, firstName: 'Ron', lastName: 'Anderson');

      expect(result, equals(tMember));
      verify(
        () => repository.update(
          id: tId,
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
          emergencyContactName: any(named: 'emergencyContactName'),
        emergencyContactPhone: any(named: 'emergencyContactPhone'),
        ),
      ).called(1);
    });

    test('trims names before persisting', () async {
      await sut.execute(
          id: tId,
          entityId: tEntityId,
          firstName: '  Ron  ',
          lastName: '  Anderson  ');

      verify(
        () => repository.update(
          id: tId,
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
          emergencyContactName: any(named: 'emergencyContactName'),
        emergencyContactPhone: any(named: 'emergencyContactPhone'),
        ),
      ).called(1);
    });

    test('throws MemberValidationException when lastName is empty', () async {
      expect(
        () => sut.execute(
            id: tId, entityId: tEntityId, firstName: 'Ron', lastName: ''),
        throwsA(isA<MemberValidationException>()),
      );
      verifyNever(() => repository.update(
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
          ));
    });

    test('propagates MemberNotFoundException from repository', () async {
      when(
        () => repository.update(
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
        ),
      ).thenThrow(MemberNotFoundException(tId));

      expect(
        () => sut.execute(
            id: tId, entityId: tEntityId, firstName: 'Ron', lastName: 'Test'),
        throwsA(isA<MemberNotFoundException>()),
      );
    });
  });
}
