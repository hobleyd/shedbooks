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

import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';
import 'package:shedbooks_server/application/invoice/delete_invoice_use_case.dart';

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  late MockInvoiceRepository repository;
  late DeleteInvoiceUseCase sut;

  const tEntityId = 'entity-1';
  const tInvoiceId = '00000000-0000-0000-0000-000000000030';

  setUp(() {
    repository = MockInvoiceRepository();
    sut = DeleteInvoiceUseCase(repository);
  });

  group('DeleteInvoiceUseCase', () {
    test('delegates delete to repository with correct id and entityId',
        () async {
      // Arrange
      when(() => repository.delete(tInvoiceId, entityId: tEntityId))
          .thenAnswer((_) async {});

      // Act
      await sut.execute(tInvoiceId, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(tInvoiceId, entityId: tEntityId))
          .called(1);
    });

    test('propagates exception when invoice not found or already paid',
        () async {
      // Arrange
      when(() => repository.delete(tInvoiceId, entityId: tEntityId))
          .thenThrow(Exception('Invoice not found or already paid'));

      // Act & Assert
      expect(
        () => sut.execute(tInvoiceId, entityId: tEntityId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not found or already paid'),
        )),
      );
    });

    test('calls repository exactly once even on happy path', () async {
      // Arrange
      when(() => repository.delete(any(), entityId: any(named: 'entityId')))
          .thenAnswer((_) async {});

      // Act
      await sut.execute(tInvoiceId, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(any(), entityId: any(named: 'entityId')))
          .called(1);
    });
  });
}
