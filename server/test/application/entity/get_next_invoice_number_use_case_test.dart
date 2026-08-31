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

import 'package:shedbooks_server/application/entity/get_next_invoice_number_use_case.dart';
import 'package:shedbooks_server/domain/entities/entity_details.dart';
import 'package:shedbooks_server/domain/repositories/i_entity_details_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_invoice_repository.dart';

class MockEntityDetailsRepository extends Mock
    implements IEntityDetailsRepository {}

class MockInvoiceRepository extends Mock implements IInvoiceRepository {}

void main() {
  group('GetNextInvoiceNumberUseCase.execute', () {
    late MockEntityDetailsRepository entityRepo;
    late MockInvoiceRepository invoiceRepo;
    late GetNextInvoiceNumberUseCase sut;

    const tEntityId = 'entity-1';
    final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');

    EntityDetails _makeDetails(String format) => EntityDetails(
          entityId: tEntityId,
          name: 'Test Org',
          abn: '',
          incorporationIdentifier: '',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
          invoiceNumberFormat: format,
          assetNoFormat: 'YYYY-{S}-####',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    setUp(() {
      entityRepo = MockEntityDetailsRepository();
      invoiceRepo = MockInvoiceRepository();
      sut = GetNextInvoiceNumberUseCase(entityRepo, invoiceRepo);
    });

    test('uses WMS-YY-### default when entity has no format set', () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails(''));
      when(() => invoiceRepo.findInvoiceNumbersLike(
            any(),
            entityId: tEntityId,
          )).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.invoiceNumber, equals('WMS-$yy-001'));
      expect(result.format, equals('WMS-YY-###'));
    });

    test('uses entity format when one is configured', () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails('INV-YY-####'));
      when(() => invoiceRepo.findInvoiceNumbersLike(
            any(),
            entityId: tEntityId,
          )).thenAnswer((_) async => ['INV-$yy-0005', 'INV-$yy-0003']);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.invoiceNumber, equals('INV-$yy-0006'));
      expect(result.format, equals('INV-YY-####'));
    });

    test('queries invoice repository (not transaction repository) for existing numbers',
        () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails('WMS-YY-###'));
      when(() => invoiceRepo.findInvoiceNumbersLike(
            'WMS-$yy-%',
            entityId: tEntityId,
          )).thenAnswer((_) async => []);

      // Act
      await sut.execute(tEntityId);

      // Assert — invoice repo was queried with the correct pattern
      verify(() => invoiceRepo.findInvoiceNumbersLike(
            'WMS-$yy-%',
            entityId: tEntityId,
          )).called(1);
    });

    test('returns 001 when no prior invoices exist', () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails('WMS-YY-###'));
      when(() => invoiceRepo.findInvoiceNumbersLike(any(), entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.invoiceNumber, endsWith('-001'));
    });
  });

  group('GetNextInvoiceNumberUseCase.generateNext', () {
    final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');
    final yyyy = DateTime.now().year.toString();

    test('returns 001 for default WMS-YY-### with no prior numbers', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'WMS-YY-###',
        [],
      );

      // Assert
      expect(result, equals('WMS-$yy-001'));
    });

    test('increments the maximum existing sequential number', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'WMS-YY-###',
        ['WMS-$yy-001', 'WMS-$yy-005', 'WMS-$yy-003'],
      );

      // Assert
      expect(result, equals('WMS-$yy-006'));
    });

    test('ignores numbers from a different year prefix', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'WMS-YY-###',
        ['WMS-24-099', 'WMS-25-050'],
      );

      // Assert — prior years are irrelevant; starts at 001
      expect(result, equals('WMS-$yy-001'));
    });

    test('pads number to hash-count width', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'INV-YYYY-#####',
        ['INV-$yyyy-00099'],
      );

      // Assert
      expect(result, equals('INV-$yyyy-00100'));
    });

    test('returns resolved format unchanged when no # tokens present', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'FIXED-FORMAT',
        [],
      );

      // Assert
      expect(result, equals('FIXED-FORMAT'));
    });

    test('handles suffix after sequential digits', () {
      // Arrange / Act
      final result = GetNextInvoiceNumberUseCase.generateNext(
        'YY-##-END',
        ['$yy-07-END'],
      );

      // Assert
      expect(result, equals('$yy-08-END'));
    });
  });
}
