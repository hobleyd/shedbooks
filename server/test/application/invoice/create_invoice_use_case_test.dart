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
import 'package:shedbooks_server/application/invoice/create_invoice_use_case.dart';

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  late MockInvoiceRepository repository;
  late CreateInvoiceUseCase sut;

  const tEntityId = 'entity-1';
  const tContactId = '00000000-0000-0000-0000-000000000010';
  const tGlId = '00000000-0000-0000-0000-000000000020';
  const tBankAccountId = '00000000-0000-0000-0000-000000000040';
  final tDate = DateTime.utc(2026, 6, 1);

  final tLineItems = [
    InvoiceLineItemInput(
      description: 'Annual membership',
      generalLedgerId: tGlId,
      amountCents: 5000,
      gstCents: 500,
    ),
    InvoiceLineItemInput(
      description: 'Tool fee',
      generalLedgerId: tGlId,
      amountCents: 2000,
      gstCents: 200,
    ),
  ];

  final tInvoiceLineItems = [
    InvoiceLineItem(
      id: '00000000-0000-0000-0000-000000000031',
      invoiceId: '00000000-0000-0000-0000-000000000030',
      description: 'Annual membership',
      generalLedgerId: tGlId,
      amountCents: 5000,
      gstCents: 500,
      createdAt: DateTime.utc(2026, 6, 1),
    ),
    InvoiceLineItem(
      id: '00000000-0000-0000-0000-000000000032',
      invoiceId: '00000000-0000-0000-0000-000000000030',
      description: 'Tool fee',
      generalLedgerId: tGlId,
      amountCents: 2000,
      gstCents: 200,
      createdAt: DateTime.utc(2026, 6, 1),
    ),
  ];

  final tInvoice = Invoice(
    id: '00000000-0000-0000-0000-000000000030',
    entityId: tEntityId,
    invoiceNumber: 'WMS-26-001',
    invoiceDate: tDate,
    contactId: tContactId,
    totalAmountCents: 7000,
    totalGstCents: 700,
    bankAccountId: tBankAccountId,
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
    lineItems: tInvoiceLineItems,
  );

  setUp(() {
    repository = MockInvoiceRepository();
    sut = CreateInvoiceUseCase(repository);
    registerFallbackValue(tDate);
    registerFallbackValue(<InvoiceLineItemInput>[]);
  });

  group('CreateInvoiceUseCase', () {
    test('delegates to repository with correct parameters and returns invoice',
        () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          invoiceNumber: 'WMS-26-001',
          invoiceDate: tDate,
          contactId: tContactId,
          lineItems: tLineItems,
          bankAccountId: tBankAccountId,
        ),
      ).thenAnswer((_) async => tInvoice);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-001',
        invoiceDate: tDate,
        contactId: tContactId,
        lineItems: tLineItems,
        bankAccountId: tBankAccountId,
      );

      // Assert
      expect(result.id, equals(tInvoice.id));
      expect(result.invoiceNumber, equals('WMS-26-001'));
      expect(result.contactId, equals(tContactId));
      expect(result.totalAmountCents, equals(7000));
      expect(result.totalGstCents, equals(700));
      expect(result.bankAccountId, equals(tBankAccountId));
      verify(
        () => repository.create(
          entityId: tEntityId,
          invoiceNumber: 'WMS-26-001',
          invoiceDate: tDate,
          contactId: tContactId,
          lineItems: tLineItems,
          bankAccountId: tBankAccountId,
        ),
      ).called(1);
    });

    test('returns invoice with populated line items', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: any(named: 'entityId'),
          invoiceNumber: any(named: 'invoiceNumber'),
          invoiceDate: any(named: 'invoiceDate'),
          contactId: any(named: 'contactId'),
          lineItems: any(named: 'lineItems'),
        ),
      ).thenAnswer((_) async => tInvoice);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-001',
        invoiceDate: tDate,
        contactId: tContactId,
        lineItems: tLineItems,
      );

      // Assert — line items are returned so the client can confirm what was saved
      expect(result.lineItems.length, equals(2));
      expect(result.lineItems[0].description, equals('Annual membership'));
      expect(result.lineItems[0].amountCents, equals(5000));
      expect(result.lineItems[1].description, equals('Tool fee'));
      expect(result.lineItems[1].amountCents, equals(2000));
    });

    test('totalWithGstCents equals totalAmountCents plus totalGstCents', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: any(named: 'entityId'),
          invoiceNumber: any(named: 'invoiceNumber'),
          invoiceDate: any(named: 'invoiceDate'),
          contactId: any(named: 'contactId'),
          lineItems: any(named: 'lineItems'),
        ),
      ).thenAnswer((_) async => tInvoice);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-001',
        invoiceDate: tDate,
        contactId: tContactId,
        lineItems: tLineItems,
      );

      // Assert
      expect(result.totalWithGstCents,
          equals(result.totalAmountCents + result.totalGstCents));
    });

    test('newly created invoice is not paid', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: any(named: 'entityId'),
          invoiceNumber: any(named: 'invoiceNumber'),
          invoiceDate: any(named: 'invoiceDate'),
          contactId: any(named: 'contactId'),
          lineItems: any(named: 'lineItems'),
        ),
      ).thenAnswer((_) async => tInvoice);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        invoiceNumber: 'WMS-26-001',
        invoiceDate: tDate,
        contactId: tContactId,
        lineItems: tLineItems,
      );

      // Assert
      expect(result.isPaid, isFalse);
      expect(result.paidAt, isNull);
    });
  });
}
