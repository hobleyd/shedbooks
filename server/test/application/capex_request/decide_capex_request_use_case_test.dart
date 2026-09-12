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

import 'package:shedbooks_server/application/capex_request/decide_capex_request_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/enums/capex_request_status.dart';
import 'package:shedbooks_server/domain/exceptions/capex_request_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late DecideCapexRequestUseCase sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000001';
  final tDate = DateTime.utc(2026, 7, 1);

  CapexRequest makeRequest({CapexRequestStatus status = CapexRequestStatus.pending}) =>
      CapexRequest(
        id: tId,
        entityId: tEntityId,
        requestNo: 'CER 26-012',
        requestDate: tDate,
        preparedByName: 'Rob Purves',
        description: 'Signs',
        whatIsRequested: 'Signs',
        needOrBenefit: 'Visibility',
        purchaseCostCents: 54450,
        totalAmountCents: 54450,
        status: status,
        createdAt: tDate,
        updatedAt: tDate,
      );

  setUp(() {
    repository = MockCapexRequestRepository();
    sut = DecideCapexRequestUseCase(repository);
    registerFallbackValue(CapexRequestStatus.pending);
  });

  group('DecideCapexRequestUseCase', () {
    test('approves a pending request', () async {
      // Arrange
      final decided = makeRequest(status: CapexRequestStatus.approved);
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => makeRequest());
      when(() => repository.decide(
            id: tId,
            entityId: tEntityId,
            status: CapexRequestStatus.approved,
            decisionByName: 'John President',
            decisionNotes: 'Looks good',
          )).thenAnswer((_) async => decided);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        status: CapexRequestStatus.approved,
        decisionByName: '  John President  ',
        decisionNotes: '  Looks good  ',
      );

      // Assert
      expect(result.status, equals(CapexRequestStatus.approved));
      verify(() => repository.decide(
            id: tId,
            entityId: tEntityId,
            status: CapexRequestStatus.approved,
            decisionByName: 'John President',
            decisionNotes: 'Looks good',
          )).called(1);
    });

    test('rejects a pending request', () async {
      // Arrange
      final decided = makeRequest(status: CapexRequestStatus.rejected);
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => makeRequest());
      when(() => repository.decide(
            id: tId,
            entityId: tEntityId,
            status: CapexRequestStatus.rejected,
            decisionByName: 'John President',
            decisionNotes: null,
          )).thenAnswer((_) async => decided);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        status: CapexRequestStatus.rejected,
        decisionByName: 'John President',
      );

      // Assert
      expect(result.status, equals(CapexRequestStatus.rejected));
    });

    test('throws CapexRequestValidationException when status is pending', () async {
      // Act + Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          status: CapexRequestStatus.pending,
          decisionByName: 'John President',
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
      verifyNever(() => repository.findById(any(), entityId: any(named: 'entityId')));
    });

    test('throws CapexRequestValidationException when decisionByName is blank',
        () async {
      // Act + Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          status: CapexRequestStatus.approved,
          decisionByName: '   ',
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
    });

    test('throws CapexRequestNotFoundException when request does not exist',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act + Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          status: CapexRequestStatus.approved,
          decisionByName: 'John President',
        ),
        throwsA(isA<CapexRequestNotFoundException>()),
      );
    });

    test('throws CapexRequestValidationException when already decided', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId)).thenAnswer(
          (_) async => makeRequest(status: CapexRequestStatus.rejected));

      // Act + Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          status: CapexRequestStatus.approved,
          decisionByName: 'John President',
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
      verifyNever(() => repository.decide(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            status: any(named: 'status'),
            decisionByName: any(named: 'decisionByName'),
          ));
    });
  });
}
