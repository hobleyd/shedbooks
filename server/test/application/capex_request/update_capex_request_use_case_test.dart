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

import 'package:shedbooks_server/application/capex_request/update_capex_request_use_case.dart';
import 'package:shedbooks_server/domain/entities/capex_request.dart';
import 'package:shedbooks_server/domain/entities/invoice.dart';
import 'package:shedbooks_server/domain/enums/capex_request_status.dart';
import 'package:shedbooks_server/domain/exceptions/capex_request_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late MockInvoiceRepository invoices;
  late UpdateCapexRequestUseCase sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000001';
  final tDate = DateTime.utc(2026, 7, 1);

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
    invoices = MockInvoiceRepository();
    sut = UpdateCapexRequestUseCase(repository, invoices);
    registerFallbackValue(tDate);
  });

  group('UpdateCapexRequestUseCase', () {
    test('updates a pending request and returns the result', () async {
      // Arrange
      final updated = makeRequest();
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => makeRequest());
      when(() => repository.update(
            id: tId,
            entityId: tEntityId,
            requestNo: 'CER 26-012',
            requestDate: tDate,
            preparedByName: 'Rob Purves',
            description: 'Signs',
            whatIsRequested: 'Signs',
            needOrBenefit: 'Visibility',
            alternativesConsidered: null,
            purchaseCostCents: 54450,
            ongoingCostsCents: null,
            otherCostsCents: null,
            costNotes: null,
            totalAmountCents: 54450,
            quotesReceivedCount: null,
          )).thenAnswer((_) async => updated);

      // Act
      final result = await sut.execute(
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
      );

      // Assert
      expect(result.id, equals(tId));
      verify(() => repository.update(
            id: tId,
            entityId: tEntityId,
            requestNo: 'CER 26-012',
            requestDate: tDate,
            preparedByName: 'Rob Purves',
            description: 'Signs',
            whatIsRequested: 'Signs',
            needOrBenefit: 'Visibility',
            alternativesConsidered: null,
            purchaseCostCents: 54450,
            ongoingCostsCents: null,
            otherCostsCents: null,
            costNotes: null,
            totalAmountCents: 54450,
            quotesReceivedCount: null,
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
          requestNo: 'CER 26-012',
          requestDate: tDate,
          preparedByName: 'Rob Purves',
          description: 'Signs',
          whatIsRequested: 'Signs',
          needOrBenefit: 'Visibility',
          purchaseCostCents: 54450,
          totalAmountCents: 54450,
        ),
        throwsA(isA<CapexRequestNotFoundException>()),
      );
    });

    test('throws CapexRequestValidationException when request already decided',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId)).thenAnswer(
          (_) async => makeRequest(status: CapexRequestStatus.approved));

      // Act + Assert
      expect(
        () => sut.execute(
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
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
      verifyNever(() => repository.update(
            id: any(named: 'id'),
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

    test('throws CapexRequestValidationException before checking existence when fields invalid',
        () async {
      // Act + Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          requestNo: '',
          requestDate: tDate,
          preparedByName: 'Rob Purves',
          description: 'Signs',
          whatIsRequested: 'Signs',
          needOrBenefit: 'Visibility',
          purchaseCostCents: 54450,
          totalAmountCents: 54450,
        ),
        throwsA(isA<CapexRequestValidationException>()),
      );
      verifyNever(() => repository.findById(any(), entityId: any(named: 'entityId')));
    });

    Future<CapexRequest> update({
      String? invoiceId,
      bool allowDecided = false,
    }) =>
        sut.execute(
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
          invoiceId: invoiceId,
          allowDecided: allowDecided,
        );

    void stubRepositoryUpdate() {
      when(() => repository.update(
            id: any(named: 'id'),
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
          )).thenAnswer((_) async => makeRequest());
    }

    test('updates an already-decided request when allowDecided is true',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId)).thenAnswer(
          (_) async => makeRequest(status: CapexRequestStatus.approved));
      stubRepositoryUpdate();

      // Act
      await update(allowDecided: true);

      // Assert
      verify(() => repository.update(
            id: any(named: 'id'),
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
          )).called(1);
    });

    test('passes a linked invoice belonging to the entity to the repository',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => makeRequest());
      when(() => invoices.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => tInvoice);
      stubRepositoryUpdate();

      // Act
      await update(invoiceId: tInvoiceId);

      // Assert
      verify(() => repository.update(
            id: any(named: 'id'),
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
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => makeRequest());
      when(() => invoices.findById(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act + Assert
      await expectLater(
        () => update(invoiceId: tInvoiceId),
        throwsA(isA<CapexRequestValidationException>()),
      );
      verifyNever(() => repository.update(
            id: any(named: 'id'),
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
