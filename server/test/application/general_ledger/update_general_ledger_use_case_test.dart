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
  const tEntityId = 'entity-1';
  final tUpdated = GeneralLedger(
    id: tId,
    label: 'Office Supplies',
    description: 'Stationery and consumables',
    gstApplicable: true,
    direction: GlDirection.moneyOut,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  setUpAll(() => registerFallbackValue(GlDirection.moneyIn));

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
          entityId: tEntityId,
          label: 'Office Supplies',
          description: 'Stationery and consumables',
          gstApplicable: true,
          direction: GlDirection.moneyOut,
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        label: 'Office Supplies',
        description: 'Stationery and consumables',
        gstApplicable: true,
        direction: GlDirection.moneyOut,
      );

      // Assert
      expect(result, equals(tUpdated));
    });

    test('trims whitespace before calling repository', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          label: 'Office Supplies',
          description: 'Stationery and consumables',
          gstApplicable: false,
          direction: GlDirection.moneyIn,
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      await sut.execute(
        id: tId,
        entityId: tEntityId,
        label: '  Office Supplies  ',
        description: '  Stationery and consumables  ',
        gstApplicable: false,
        direction: GlDirection.moneyIn,
      );

      // Assert
      verify(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          label: 'Office Supplies',
          description: 'Stationery and consumables',
          gstApplicable: false,
          direction: GlDirection.moneyIn,
        ),
      ).called(1);
    });

    test('throws GeneralLedgerValidationException when label is empty',
        () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          label: '',
          description: 'desc',
          gstApplicable: true,
          direction: GlDirection.moneyIn,
        ),
        throwsA(isA<GeneralLedgerValidationException>()),
      );
    });

    test('throws GeneralLedgerNotFoundException propagated from repository',
        () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          label: any(named: 'label'),
          description: any(named: 'description'),
          gstApplicable: any(named: 'gstApplicable'),
          direction: any(named: 'direction'),
        ),
      ).thenThrow(GeneralLedgerNotFoundException(tId));

      // Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          label: 'Valid',
          description: 'Valid',
          gstApplicable: false,
          direction: GlDirection.moneyIn,
        ),
        throwsA(isA<GeneralLedgerNotFoundException>()),
      );
    });
  });
}
