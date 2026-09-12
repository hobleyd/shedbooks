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

import 'package:shedbooks_server/application/capex_request/get_capex_request_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/exceptions/capex_request_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late GetCapexRequestUseCase sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000001';
  final tDate = DateTime.utc(2026, 7, 1);

  setUp(() {
    repository = MockCapexRequestRepository();
    sut = GetCapexRequestUseCase(repository);
  });

  group('GetCapexRequestUseCase', () {
    test('returns the request when found', () async {
      // Arrange
      final request = CapexRequest(
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
        createdAt: tDate,
        updatedAt: tDate,
      );
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => request);

      // Act
      final result = await sut.execute(tId, entityId: tEntityId);

      // Assert
      expect(result.id, equals(tId));
    });

    test('throws CapexRequestNotFoundException when not found', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act + Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<CapexRequestNotFoundException>()),
      );
    });
  });
}
