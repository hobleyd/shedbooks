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
import 'package:shedbooks_server/application/invoice/list_invoices_use_case.dart';

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  late MockInvoiceRepository repository;
  late ListInvoicesUseCase sut;

  const tEntityId = 'entity-1';
  final tNow = DateTime.utc(2026, 6, 1);

  Invoice _makeInvoice(String number, {DateTime? paidAt}) => Invoice(
        id: 'inv-$number',
        entityId: tEntityId,
        invoiceNumber: number,
        invoiceDate: DateTime.utc(2026, 6, 1),
        contactId: 'contact-1',
        totalAmountCents: 10000,
        totalGstCents: 1000,
        paidAt: paidAt,
        createdAt: tNow,
        updatedAt: tNow,
      );

  setUp(() {
    repository = MockInvoiceRepository();
    sut = ListInvoicesUseCase(repository);
  });

  group('ListInvoicesUseCase', () {
    test('returns all invoices when unpaidOnly is false (default)', () async {
      // Arrange
      final tInvoices = [
        _makeInvoice('WMS-26-001'),
        _makeInvoice('WMS-26-002', paidAt: tNow),
        _makeInvoice('WMS-26-003'),
      ];
      when(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: false,
          )).thenAnswer((_) async => tInvoices);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.length, equals(3));
      verify(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: false,
          )).called(1);
    });

    test('passes unpaidOnly: true to repository when requested', () async {
      // Arrange
      final tUnpaid = [
        _makeInvoice('WMS-26-001'),
        _makeInvoice('WMS-26-003'),
      ];
      when(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: true,
          )).thenAnswer((_) async => tUnpaid);

      // Act
      final result = await sut.execute(tEntityId, unpaidOnly: true);

      // Assert
      expect(result.length, equals(2));
      expect(result.every((i) => !i.isPaid), isTrue);
      verify(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: true,
          )).called(1);
    });

    test('returns empty list when no invoices exist', () async {
      // Arrange
      when(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: false,
          )).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, isEmpty);
    });

    test('isPaid is true for invoices with a paidAt timestamp', () async {
      // Arrange
      final tInvoices = [
        _makeInvoice('WMS-26-001', paidAt: tNow),
      ];
      when(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: false,
          )).thenAnswer((_) async => tInvoices);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.first.isPaid, isTrue);
    });

    test('isPaid is false for invoices without a paidAt timestamp', () async {
      // Arrange
      final tInvoices = [_makeInvoice('WMS-26-002')];
      when(() => repository.findAll(
            entityId: tEntityId,
            unpaidOnly: false,
          )).thenAnswer((_) async => tInvoices);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.first.isPaid, isFalse);
    });
  });
}
