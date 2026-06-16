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

import 'package:shedbooks_server/domain/entities/bank_import.dart';
import 'package:shedbooks_server/domain/repositories/i_bank_import_repository.dart';
import 'package:shedbooks_server/application/bank_import/save_bank_imports_use_case.dart';

class MockBankImportRepository extends Mock implements IBankImportRepository {}

void main() {
  late MockBankImportRepository repository;
  late SaveBankImportsUseCase sut;

  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockBankImportRepository();
    sut = SaveBankImportsUseCase(repository);
    registerFallbackValue(<BankImport>[]);
  });

  group('SaveBankImportsUseCase', () {
    test('calls repository.saveAll with correct entities', () async {
      // Arrange
      when(() => repository.saveAll(any())).thenAnswer((_) async {});

      // Act
      await sut.execute(
        entityId: tEntityId,
        rows: [
          (
            processDate: '2026-05-01',
            description: 'Payment P-26001',
            amountCents: 5000,
            isDebit: true,
          ),
          (
            processDate: '2026-05-02',
            description: 'Transfer in',
            amountCents: 10000,
            isDebit: false,
          ),
        ],
      );

      // Assert
      final captured =
          verify(() => repository.saveAll(captureAny())).captured.single
              as List<BankImport>;
      expect(captured.length, equals(2));
      expect(captured[0].entityId, equals(tEntityId));
      expect(captured[0].processDate, equals('2026-05-01'));
      expect(captured[0].description, equals('Payment P-26001'));
      expect(captured[0].amountCents, equals(5000));
      expect(captured[0].isDebit, isTrue);
      expect(captured[1].entityId, equals(tEntityId));
      expect(captured[1].isDebit, isFalse);
    });

    test('does not call repository when rows list is empty', () async {
      // Act
      await sut.execute(entityId: tEntityId, rows: []);

      // Assert
      verifyNever(() => repository.saveAll(any()));
    });

    test('saves a single row correctly', () async {
      // Arrange
      when(() => repository.saveAll(any())).thenAnswer((_) async {});

      // Act
      await sut.execute(
        entityId: tEntityId,
        rows: [
          (
            processDate: '2026-05-10',
            description: 'P26062-67,69',
            amountCents: 35000,
            isDebit: true,
          ),
        ],
      );

      // Assert
      final captured =
          verify(() => repository.saveAll(captureAny())).captured.single
              as List<BankImport>;
      expect(captured.length, equals(1));
      expect(captured[0].processDate, equals('2026-05-10'));
    });
  });
}
