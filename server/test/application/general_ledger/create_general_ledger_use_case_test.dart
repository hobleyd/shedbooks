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

  final tAccount = GeneralLedger(
    id: '00000000-0000-0000-0000-000000000001',
    label: 'Sales Revenue',
    description: 'Revenue from product sales',
    gstApplicable: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = CreateGeneralLedgerUseCase(repository);
  });

  group('CreateGeneralLedgerUseCase', () {
    test('creates account and returns the persisted entity', () async {
      // Arrange
      when(
        () => repository.create(
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: true,
        ),
      ).thenAnswer((_) async => tAccount);

      // Act
      final result = await sut.execute(
        label: 'Sales Revenue',
        description: 'Revenue from product sales',
        gstApplicable: true,
      );

      // Assert
      expect(result, equals(tAccount));
      verify(
        () => repository.create(
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: true,
        ),
      ).called(1);
    });

    test('trims whitespace from label and description before persisting', () async {
      // Arrange
      when(
        () => repository.create(
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: false,
        ),
      ).thenAnswer((_) async => tAccount);

      // Act
      await sut.execute(
        label: '  Sales Revenue  ',
        description: '  Revenue from product sales  ',
        gstApplicable: false,
      );

      // Assert
      verify(
        () => repository.create(
          label: 'Sales Revenue',
          description: 'Revenue from product sales',
          gstApplicable: false,
        ),
      ).called(1);
    });

    test('throws GeneralLedgerValidationException when label is empty', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(label: '  ', description: 'desc', gstApplicable: false),
        throwsA(isA<GeneralLedgerValidationException>()),
      );
      verifyNever(() => repository.create(
            label: any(named: 'label'),
            description: any(named: 'description'),
            gstApplicable: any(named: 'gstApplicable'),
          ));
    });

    test('throws GeneralLedgerValidationException when description is empty', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(label: 'Sales', description: '   ', gstApplicable: true),
        throwsA(isA<GeneralLedgerValidationException>()),
      );
      verifyNever(() => repository.create(
            label: any(named: 'label'),
            description: any(named: 'description'),
            gstApplicable: any(named: 'gstApplicable'),
          ));
    });
  });
}
