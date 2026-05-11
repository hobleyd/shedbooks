import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/bank_import.dart';
import 'package:shedbooks_server/domain/repositories/i_bank_import_repository.dart';
import 'package:shedbooks_server/application/bank_import/get_bank_imports_use_case.dart';

class MockBankImportRepository extends Mock implements IBankImportRepository {}

void main() {
  late MockBankImportRepository repository;
  late GetBankImportsUseCase sut;

  const tEntityId = 'entity-1';
  final tRows = [
    BankImport(
      id: 'id-1',
      entityId: tEntityId,
      processDate: '2026-05-01',
      description: 'Payment P-26001',
      amountCents: 5000,
      isDebit: true,
      importedAt: DateTime.utc(2026, 5, 11),
    ),
    BankImport(
      id: 'id-2',
      entityId: tEntityId,
      processDate: '2026-05-02',
      description: 'Transfer from CommBank app 5911431',
      amountCents: 10000,
      isDebit: false,
      importedAt: DateTime.utc(2026, 5, 11),
    ),
  ];

  setUp(() {
    repository = MockBankImportRepository();
    sut = GetBankImportsUseCase(repository);
  });

  group('GetBankImportsUseCase', () {
    test('returns all rows from repository', () async {
      // Arrange
      when(() => repository.findAll(tEntityId)).thenAnswer((_) async => tRows);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, equals(tRows));
      verify(() => repository.findAll(tEntityId)).called(1);
    });

    test('returns empty list when no rows exist', () async {
      // Arrange
      when(() => repository.findAll(tEntityId)).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
