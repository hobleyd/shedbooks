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

import 'package:shedbooks_server/domain/entities/invoice.dart';
import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';
import 'package:shedbooks_server/application/invoice/update_invoice_use_case.dart';

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  late MockInvoiceRepository repository;
  late UpdateInvoiceUseCase sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000030';
  const tGlId = '00000000-0000-0000-0000-000000000020';
  final tDate = DateTime.utc(2026, 7, 1);
  final tNow = DateTime.utc(2026, 7, 1);

  final tLineItems = [
    InvoiceLineItemInput(
      description: 'Updated membership',
      generalLedgerId: tGlId,
      amountCents: 6000,
      gstCents: 600,
    ),
  ];

  final tUpdatedLineItems = [
    InvoiceLineItem(
      id: '00000000-0000-0000-0000-000000000031',
      invoiceId: tId,
      description: 'Updated membership',
      generalLedgerId: tGlId,
      amountCents: 6000,
      gstCents: 600,
      createdAt: tNow,
    ),
  ];

  final tUpdatedInvoice = Invoice(
    id: tId,
    entityId: tEntityId,
    invoiceNumber: 'WMS-26-002',
    invoiceDate: tDate,
    contactId: 'contact-1',
    totalAmountCents: 6000,
    totalGstCents: 600,
    createdAt: tNow,
    updatedAt: tNow,
    lineItems: tUpdatedLineItems,
  );

  setUp(() {
    repository = MockInvoiceRepository();
    sut = UpdateInvoiceUseCase(repository);
    registerFallbackValue(tDate);
    registerFallbackValue(<InvoiceLineItemInput>[]);
  });

  group('UpdateInvoiceUseCase', () {
    test('delegates to repository with correct parameters and returns invoice',
        () async {
      // Arrange
      when(() => repository.update(
            id: tId,
            entityId: tEntityId,
            invoiceNumber: 'WMS-26-002',
            invoiceDate: tDate,
            lineItems: tLineItems,
          )).thenAnswer((_) async => tUpdatedInvoice);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-002',
        invoiceDate: tDate,
        lineItems: tLineItems,
      );

      // Assert
      expect(result.id, equals(tId));
      expect(result.invoiceNumber, equals('WMS-26-002'));
      expect(result.totalAmountCents, equals(6000));
      expect(result.totalGstCents, equals(600));
      verify(() => repository.update(
            id: tId,
            entityId: tEntityId,
            invoiceNumber: 'WMS-26-002',
            invoiceDate: tDate,
            lineItems: tLineItems,
          )).called(1);
    });

    test('returns updated invoice with new line items', () async {
      // Arrange
      when(() => repository.update(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            invoiceNumber: any(named: 'invoiceNumber'),
            invoiceDate: any(named: 'invoiceDate'),
            lineItems: any(named: 'lineItems'),
          )).thenAnswer((_) async => tUpdatedInvoice);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-002',
        invoiceDate: tDate,
        lineItems: tLineItems,
      );

      // Assert
      expect(result.lineItems.length, equals(1));
      expect(result.lineItems.first.description, equals('Updated membership'));
      expect(result.lineItems.first.amountCents, equals(6000));
    });

    test('propagates exception when invoice is not found or already paid',
        () async {
      // Arrange
      when(() => repository.update(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            invoiceNumber: any(named: 'invoiceNumber'),
            invoiceDate: any(named: 'invoiceDate'),
            lineItems: any(named: 'lineItems'),
          )).thenThrow(Exception('Invoice not found or already paid'));

      // Act & Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          invoiceNumber: 'WMS-26-002',
          invoiceDate: tDate,
          lineItems: tLineItems,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found or already paid'),
        )),
      );
    });

    test('updated invoice is still unpaid', () async {
      // Arrange
      when(() => repository.update(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            invoiceNumber: any(named: 'invoiceNumber'),
            invoiceDate: any(named: 'invoiceDate'),
            lineItems: any(named: 'lineItems'),
          )).thenAnswer((_) async => tUpdatedInvoice);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-002',
        invoiceDate: tDate,
        lineItems: tLineItems,
      );

      // Assert — only unpaid invoices can be updated; result must still be unpaid
      expect(result.isPaid, isFalse);
      expect(result.paidAt, isNull);
    });
  });
}
