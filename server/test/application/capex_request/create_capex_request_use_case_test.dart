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
import 'package:shedbooks_server/domain/entities/invoice.dart';
import 'package:shedbooks_server/domain/exceptions/capex_request_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late MockInvoiceRepository invoices;
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

  const tInvoiceId = '00000000-0000-0000-0000-0000000000aa';
  final Invoice tInvoice = Invoice(
    id: tInvoiceId,
    entityId: tEntityId,
    invoiceNumber: 'WMS-26-001',
    invoiceDate: DateTime.utc(2026, 7, 1),
    contactId: 'contact-1',
    totalAmountCents: 50000,
    totalGstCents: 5000,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  setUp(() {
    repository = MockCapexRequestRepository();
    invoices = MockInvoiceRepository();
    sut = CreateCapexRequestUseCase(repository, invoices);
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

    Future<CapexRequest> create({String? invoiceId}) => sut.execute(
          entityId: tEntityId,
          requestNo: 'CER 26-012',
          requestDate: tDate,
          preparedByName: 'Rob Purves',
          description: 'Signs',
          whatIsRequested: 'Signs',
          needOrBenefit: 'Visibility',
          purchaseCostCents: 54450,
          totalAmountCents: 54450,
          invoiceId: invoiceId,
        );

    test('passes a linked invoice belonging to the entity to the repository',
        () async {
      // Arrange
      when(() => invoices.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tInvoice);
      when(() => repository.create(
            entityId: any(named: 'entityId'),
            requestNo: any(named: 'requestNo'),
            requestDate: any(named: 'requestDate'),
            preparedByName: any(named: 'preparedByName'),
            description: any(named: 'description'),
            whatIsRequested: any(named: 'whatIsRequested'),
            needOrBenefit: any(named: 'needOrBenefit'),
            alternativesConsidered: any(named: 'alternativesConsidered'),
            purchaseCostCents: any(named: 'purchaseCostCents'),
            ongoingCostsCents: any(named: 'ongoingCostsCents'),
            otherCostsCents: any(named: 'otherCostsCents'),
            costNotes: any(named: 'costNotes'),
            totalAmountCents: any(named: 'totalAmountCents'),
            quotesReceivedCount: any(named: 'quotesReceivedCount'),
            invoiceId: any(named: 'invoiceId'),
          )).thenAnswer((_) async => tRequest);

      // Act
      await create(invoiceId: tInvoiceId);

      // Assert
      verify(() => repository.create(
            entityId: any(named: 'entityId'),
            requestNo: any(named: 'requestNo'),
            requestDate: any(named: 'requestDate'),
            preparedByName: any(named: 'preparedByName'),
            description: any(named: 'description'),
            whatIsRequested: any(named: 'whatIsRequested'),
            needOrBenefit: any(named: 'needOrBenefit'),
            alternativesConsidered: any(named: 'alternativesConsidered'),
            purchaseCostCents: any(named: 'purchaseCostCents'),
            ongoingCostsCents: any(named: 'ongoingCostsCents'),
            otherCostsCents: any(named: 'otherCostsCents'),
            costNotes: any(named: 'costNotes'),
            totalAmountCents: any(named: 'totalAmountCents'),
            quotesReceivedCount: any(named: 'quotesReceivedCount'),
            invoiceId: tInvoiceId,
          )).called(1);
    });

    test('throws CapexRequestValidationException when the linked invoice is not in the entity',
        () async {
      // Arrange
      when(() => invoices.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act + Assert
      await expectLater(
        () => create(invoiceId: tInvoiceId),
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
            alternativesConsidered: any(named: 'alternativesConsidered'),
            purchaseCostCents: any(named: 'purchaseCostCents'),
            ongoingCostsCents: any(named: 'ongoingCostsCents'),
            otherCostsCents: any(named: 'otherCostsCents'),
            costNotes: any(named: 'costNotes'),
            totalAmountCents: any(named: 'totalAmountCents'),
            quotesReceivedCount: any(named: 'quotesReceivedCount'),
            invoiceId: any(named: 'invoiceId'),
          ));
    });
  });
}
