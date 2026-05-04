import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/exceptions/general_ledger_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/delete_general_ledger_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late DeleteGeneralLedgerUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  final tAccount = GeneralLedger(
    id: tId,
    label: 'Wages',
    description: 'Employee wages expense',
    gstApplicable: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = DeleteGeneralLedgerUseCase(repository);
  });

  group('DeleteGeneralLedgerUseCase', () {
    test('calls repository delete when account exists', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => tAccount);
      when(() => repository.delete(tId)).thenAnswer((_) async {});

      // Act
      await sut.execute(tId);

      // Assert
      verify(() => repository.delete(tId)).called(1);
    });

    test('throws GeneralLedgerNotFoundException when account does not exist', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId),
        throwsA(isA<GeneralLedgerNotFoundException>()),
      );
      verifyNever(() => repository.delete(any()));
    });
  });
}
