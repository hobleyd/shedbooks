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

import 'package:shedbooks_server/application/capex_request/set_capex_request_executed_date_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/enums/capex_request_status.dart';
import 'package:shedbooks_server/domain/exceptions/capex_request_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late SetCapexRequestExecutedDateUseCase sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000001';
  final tDate = DateTime.utc(2026, 7, 1);
  final tExecutedDate = DateTime.utc(2026, 8, 15);

  CapexRequest makeRequest({
    CapexRequestStatus status = CapexRequestStatus.approved,
    DateTime? executedDate,
  }) =>
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
        executedDate: executedDate,
        createdAt: tDate,
        updatedAt: tDate,
      );

  setUp(() {
    repository = MockCapexRequestRepository();
    sut = SetCapexRequestExecutedDateUseCase(repository);
  });

  group('SetCapexRequestExecutedDateUseCase', () {
    test('sets the executed date on an approved request', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => makeRequest());
      when(() => repository.setExecutedDate(
            id: tId,
            entityId: tEntityId,
            executedDate: tExecutedDate,
          )).thenAnswer(
              (_) async => makeRequest(executedDate: tExecutedDate));

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        executedDate: tExecutedDate,
      );

      // Assert
      expect(result.executedDate, equals(tExecutedDate));
      verify(() => repository.setExecutedDate(
            id: tId,
            entityId: tEntityId,
            executedDate: tExecutedDate,
          )).called(1);
    });

    test('allows setting an executed date on a still-pending request',
        () async {
      // Arrange — execution can be recorded before a decision is finalised.
      when(() => repository.findById(tId, entityId: tEntityId)).thenAnswer(
          (_) async => makeRequest(status: CapexRequestStatus.pending));
      when(() => repository.setExecutedDate(
            id: tId,
            entityId: tEntityId,
            executedDate: tExecutedDate,
          )).thenAnswer((_) async => makeRequest(
          status: CapexRequestStatus.pending, executedDate: tExecutedDate));

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        executedDate: tExecutedDate,
      );

      // Assert
      expect(result.executedDate, equals(tExecutedDate));
    });

    test('clears the executed date when passed null', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId)).thenAnswer(
          (_) async => makeRequest(executedDate: tExecutedDate));
      when(() => repository.setExecutedDate(
            id: tId,
            entityId: tEntityId,
            executedDate: null,
          )).thenAnswer((_) async => makeRequest());

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        executedDate: null,
      );

      // Assert
      expect(result.executedDate, isNull);
      verify(() => repository.setExecutedDate(
            id: tId,
            entityId: tEntityId,
            executedDate: null,
          )).called(1);
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
          executedDate: tExecutedDate,
        ),
        throwsA(isA<CapexRequestNotFoundException>()),
      );
      verifyNever(() => repository.setExecutedDate(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            executedDate: any(named: 'executedDate'),
          ));
    });
  });
}
