import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/exceptions/general_ledger_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/update_general_ledger_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late UpdateGeneralLedgerUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  final tUpdated = GeneralLedger(
    id: tId,
    label: 'Office Supplies',
    description: 'Stationery and consumables',
    gstApplicable: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = UpdateGeneralLedgerUseCase(repository);
  });

  group('UpdateGeneralLedgerUseCase', () {
    test('updates and returns the updated entity', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          label: 'Office Supplies',
          description: 'Stationery and consumables',
          gstApplicable: true,
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      final result = await sut.execute(
        id: tId,
        label: 'Office Supplies',
        description: 'Stationery and consumables',
        gstApplicable: true,
      );

      // Assert
      expect(result, equals(tUpdated));
    });

    test('trims whitespace before calling repository', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          label: 'Office Supplies',
          description: 'Stationery and consumables',
          gstApplicable: false,
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      await sut.execute(
        id: tId,
        label: '  Office Supplies  ',
        description: '  Stationery and consumables  ',
        gstApplicable: false,
      );

      // Assert
      verify(
        () => repository.update(
          id: tId,
          label: 'Office Supplies',
          description: 'Stationery and consumables',
          gstApplicable: false,
        ),
      ).called(1);
    });

    test('throws GeneralLedgerValidationException when label is empty', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(id: tId, label: '', description: 'desc', gstApplicable: true),
        throwsA(isA<GeneralLedgerValidationException>()),
      );
    });

    test('throws GeneralLedgerNotFoundException propagated from repository', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          label: any(named: 'label'),
          description: any(named: 'description'),
          gstApplicable: any(named: 'gstApplicable'),
        ),
      ).thenThrow(GeneralLedgerNotFoundException(tId));

      // Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          label: 'Valid',
          description: 'Valid',
          gstApplicable: false,
        ),
        throwsA(isA<GeneralLedgerNotFoundException>()),
      );
    });
  });
}
