import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/list_general_ledgers_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late ListGeneralLedgersUseCase sut;

  final tAccounts = [
    GeneralLedger(
      id: '00000000-0000-0000-0000-000000000001',
      label: 'Cash',
      description: 'Cash on hand',
      gstApplicable: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    GeneralLedger(
      id: '00000000-0000-0000-0000-000000000002',
      label: 'Sales Revenue',
      description: 'Revenue from sales',
      gstApplicable: true,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    ),
  ];

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = ListGeneralLedgersUseCase(repository);
  });

  group('ListGeneralLedgersUseCase', () {
    test('returns all active accounts from repository', () async {
      // Arrange
      when(() => repository.findAll()).thenAnswer((_) async => tAccounts);

      // Act
      final result = await sut.execute();

      // Assert
      expect(result, equals(tAccounts));
      verify(() => repository.findAll()).called(1);
    });

    test('returns empty list when no accounts exist', () async {
      // Arrange
      when(() => repository.findAll()).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute();

      // Assert
      expect(result, isEmpty);
    });
  });
}
