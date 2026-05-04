import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/exceptions/general_ledger_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/get_general_ledger_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late GetGeneralLedgerUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  final tAccount = GeneralLedger(
    id: tId,
    label: 'Cost of Goods Sold',
    description: 'Direct costs of producing goods',
    gstApplicable: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = GetGeneralLedgerUseCase(repository);
  });

  group('GetGeneralLedgerUseCase', () {
    test('returns the account when found', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => tAccount);

      // Act
      final result = await sut.execute(tId);

      // Assert
      expect(result, equals(tAccount));
    });

    test('throws GeneralLedgerNotFoundException when account does not exist', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId),
        throwsA(isA<GeneralLedgerNotFoundException>()),
      );
    });
  });
}
