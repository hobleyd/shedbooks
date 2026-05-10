import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/exceptions/general_ledger_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/create_general_ledger_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late CreateGeneralLedgerUseCase sut;

  const tEntityId = 'entity-1';
  final tAccount = GeneralLedger(
    id: '00000000-0000-0000-0000-000000000001',
    label: 'Sales Revenue',
    description: 'Revenue from product sales',
    gstApplicable: true,
    direction: GlDirection.moneyIn,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() => registerFallbackValue(GlDirection.moneyIn));

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = CreateGeneralLedgerUseCase(repository);
  });

  group('CreateGeneralLedgerUseCase', () {
    test('creates account and returns the persisted entity', () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: true,
          direction: GlDirection.moneyIn,
        ),
      ).thenAnswer((_) async => tAccount);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        label: 'Sales Revenue',
        description: 'Revenue from product sales',
        gstApplicable: true,
        direction: GlDirection.moneyIn,
      );

      // Assert
      expect(result, equals(tAccount));
      verify(
        () => repository.create(
          entityId: tEntityId,
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: true,
          direction: GlDirection.moneyIn,
        ),
      ).called(1);
    });

    test('trims whitespace from label and description before persisting',
        () async {
      // Arrange
      when(
        () => repository.create(
          entityId: tEntityId,
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: false,
          direction: GlDirection.moneyOut,
        ),
      ).thenAnswer((_) async => tAccount);

      // Act
      await sut.execute(
        entityId: tEntityId,
        label: '  Sales Revenue  ',
        description: '  Revenue from product sales  ',
        gstApplicable: false,
        direction: GlDirection.moneyOut,
      );

      // Assert
      verify(
        () => repository.create(
          entityId: tEntityId,
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: false,
          direction: GlDirection.moneyOut,
        ),
      ).called(1);
    });

    test('throws GeneralLedgerValidationException when label is empty',
        () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          label: '  ',
          description: 'desc',
          gstApplicable: false,
          direction: GlDirection.moneyIn,
        ),
        throwsA(isA<GeneralLedgerValidationException>()),
      );
      verifyNever(() => repository.create(
            entityId: any(named: 'entityId'),
            label: any(named: 'label'),
            description: any(named: 'description'),
            gstApplicable: any(named: 'gstApplicable'),
            direction: any(named: 'direction'),
          ));
    });

    test('throws GeneralLedgerValidationException when description is empty',
        () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          label: 'Sales',
          description: '   ',
          gstApplicable: true,
          direction: GlDirection.moneyIn,
        ),
        throwsA(isA<GeneralLedgerValidationException>()),
      );
    });
  });
}
