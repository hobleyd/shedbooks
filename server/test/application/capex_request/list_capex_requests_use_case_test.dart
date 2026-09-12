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

import 'package:shedbooks_server/application/capex_request/list_capex_requests_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late ListCapexRequestsUseCase sut;

  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 7, 1);

  setUp(() {
    repository = MockCapexRequestRepository();
    sut = ListCapexRequestsUseCase(repository);
  });

  test('returns all requests for the entity', () async {
    // Arrange
    final requests = [
      CapexRequest(
        id: '1',
        entityId: tEntityId,
        requestNo: 'CER 26-012',
        requestDate: tDate,
        preparedByName: 'Rob Purves',
        description: 'Signs',
        whatIsRequested: 'Signs',
        needOrBenefit: 'Visibility',
        purchaseCostCents: 54450,
        totalAmountCents: 54450,
        createdAt: tDate,
        updatedAt: tDate,
      ),
    ];
    when(() => repository.findAll(entityId: tEntityId))
        .thenAnswer((_) async => requests);

    // Act
    final result = await sut.execute(entityId: tEntityId);

    // Assert
    expect(result, equals(requests));
    verify(() => repository.findAll(entityId: tEntityId)).called(1);
  });
}
