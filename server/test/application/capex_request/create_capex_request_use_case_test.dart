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

import 'package:shedbooks_server/application/capex_request/create_capex_request_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/exceptions/capex_request_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late CreateCapexRequestUseCase sut;

  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 7, 1);

  final tRequest = CapexRequest(
    id: '00000000-0000-0000-0000-000000000001',
    entityId: tEntityId,
    requestNo: 'CER 26-012',
    requestDate: tDate,
    preparedByName: 'Rob Purves',
    description: 'Manufactures signs for Shed, Recycling, Markets and Garage Sale',
    whatIsRequested: 'Provision of various permanent signs',
    needOrBenefit: 'Replace the existing degraded sign',
    purchaseCostCents: 54450,
    ongoingCostsCents: 7800,
    totalAmountCents: 62250,
    quotesReceivedCount: 1,
    createdAt: tDate,
    updatedAt: tDate,
  );

  setUp(() {
    repository = MockCapexRequestRepository();
    sut = CreateCapexRequestUseCase(repository);
    registerFallbackValue(tDate);
  });

  group('CreateCapexRequestUseCase', () {
    test('delegates to repository with trimmed fields and returns request',
        () async {
      // Arrange
      when(() => repository.create(
            entityId: tEntityId,
            requestNo: 'CER 26-012',
            requestDate: tDate,
            preparedByName: 'Rob Purves',
            description: 'Manufactures signs',
            whatIsRequested: 'Provision of various permanent signs',
            needOrBenefit: 'Replace the existing degraded sign',
            alternativesConsidered: null,
            purchaseCostCents: 54450,
            ongoingCostsCents: 7800,
            otherCostsCents: null,
            costNotes: null,
            totalAmountCents: 62250,
            quotesReceivedCount: 1,
          )).thenAnswer((_) async => tRequest);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        requestNo: '  CER 26-012  ',
        requestDate: tDate,
        preparedByName: '  Rob Purves  ',
        description: '  Manufactures signs  ',
        whatIsRequested: 'Provision of various permanent signs',
        needOrBenefit: 'Replace the existing degraded sign',
        alternativesConsidered: '   ',
        purchaseCostCents: 54450,
        ongoingCostsCents: 7800,
        totalAmountCents: 62250,
        quotesReceivedCount: 1,
      );

      // Assert
      expect(result.id, equals(tRequest.id));
      expect(result.requestNo, equals('CER 26-012'));
      verify(() => repository.create(
            entityId: tEntityId,
            requestNo: 'CER 26-012',
            requestDate: tDate,
            preparedByName: 'Rob Purves',
            description: 'Manufactures signs',
            whatIsRequested: 'Provision of various permanent signs',
            needOrBenefit: 'Replace the existing degraded sign',
            alternativesConsidered: null,
            purchaseCostCents: 54450,
            ongoingCostsCents: 7800,
            otherCostsCents: null,
            costNotes: null,
            totalAmountCents: 62250,
            quotesReceivedCount: 1,
          )).called(1);
    });

    test('throws CapexRequestValidationException when requestNo is blank',
        () async {
      // Act + Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          requestNo: '   ',
          requestDate: tDate,
          preparedByName: 'Rob Purves',
          description: 'Description',
          whatIsRequested: 'What',
          needOrBenefit: 'Need',
          purchaseCostCents: 100,
          totalAmountCents: 100,
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
      verifyNever(() => repository.create(
            entityId: any(named: 'entityId'),
            requestNo: any(named: 'requestNo'),
            requestDate: any(named: 'requestDate'),
            preparedByName: any(named: 'preparedByName'),
            description: any(named: 'description'),
            whatIsRequested: any(named: 'whatIsRequested'),
            needOrBenefit: any(named: 'needOrBenefit'),
            purchaseCostCents: any(named: 'purchaseCostCents'),
            totalAmountCents: any(named: 'totalAmountCents'),
          ));
    });

    test('throws CapexRequestValidationException when purchaseCostCents is negative',
        () async {
      // Act + Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          requestNo: 'CER 26-012',
          requestDate: tDate,
          preparedByName: 'Rob Purves',
          description: 'Description',
          whatIsRequested: 'What',
          needOrBenefit: 'Need',
          purchaseCostCents: -1,
          totalAmountCents: 100,
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
    });

    test('throws CapexRequestValidationException when preparedByName is blank',
        () async {
      // Act + Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          requestNo: 'CER 26-012',
          requestDate: tDate,
          preparedByName: '',
          description: 'Description',
          whatIsRequested: 'What',
          needOrBenefit: 'Need',
          purchaseCostCents: 100,
          totalAmountCents: 100,
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
    });
  });
}
