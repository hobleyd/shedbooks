import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/budget_gl_mapping.dart';
import 'package:shedbooks_server/domain/entities/budget_line.dart';
import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/confirm_budget_import_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late ConfirmBudgetImportUseCase sut;

  const tEntityId = 'org-1';

  setUpAll(() {
    registerFallbackValue(<BudgetLine>[]);
    registerFallbackValue(<BudgetGlMapping>[]);
  });

  setUp(() {
    repository = MockBudgetRepository();
    sut = ConfirmBudgetImportUseCase(repository);
    when(() => repository.saveLines(any(), any(), entityId: any(named: 'entityId')))
        .thenAnswer((_) async {});
    when(() => repository.saveMappings(any(), entityId: any(named: 'entityId')))
        .thenAnswer((_) async {});
  });

  List<int> months({int jan = 0, int feb = 0, int mar = 0, int apr = 0,
      int may = 0, int jun = 0, int jul = 0, int aug = 0,
      int sep = 0, int oct = 0, int nov = 0, int dec = 0}) =>
      [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec];

  group('ConfirmBudgetImportUseCase', () {
    test('converts non-zero monthly amounts to budget lines', () async {
      // Arrange
      final row = ConfirmedImportRow(
        externalCode: 'MEMB',
        externalName: 'Memberships',
        generalLedgerId: 'gl-1',
        months: months(jan: 10000, mar: 15000),
      );

      // Act
      await sut.execute(year: 2025, rows: [row], saveMappings: false, entityId: tEntityId);

      // Assert
      final captured = verify(() => repository.saveLines(2025, captureAny(), entityId: tEntityId))
          .captured
          .first as List<BudgetLine>;
      expect(captured, hasLength(2));
      expect(captured.any((l) => l.generalLedgerId == 'gl-1' && l.month == 1 && l.amountCents == 10000), isTrue);
      expect(captured.any((l) => l.generalLedgerId == 'gl-1' && l.month == 3 && l.amountCents == 15000), isTrue);
    });

    test('excludes months with zero amount', () async {
      // Arrange
      final row = ConfirmedImportRow(
        externalCode: 'MEMB',
        externalName: 'Memberships',
        generalLedgerId: 'gl-1',
        months: months(jan: 10000),
      );

      // Act
      await sut.execute(year: 2025, rows: [row], saveMappings: false, entityId: tEntityId);

      // Assert
      final captured = verify(() => repository.saveLines(2025, captureAny(), entityId: tEntityId))
          .captured
          .first as List<BudgetLine>;
      expect(captured, hasLength(1));
    });

    test('aggregates duplicate GL/month entries by summing amounts', () async {
      // Arrange — two rows mapped to the same GL account
      final row1 = ConfirmedImportRow(
        externalCode: 'SUBS-A',
        externalName: 'Subscriptions A',
        generalLedgerId: 'gl-1',
        months: months(jan: 10000, feb: 20000),
      );
      final row2 = ConfirmedImportRow(
        externalCode: 'SUBS-B',
        externalName: 'Subscriptions B',
        generalLedgerId: 'gl-1',
        months: months(jan: 5000, feb: 8000),
      );

      // Act
      await sut.execute(year: 2025, rows: [row1, row2], saveMappings: false, entityId: tEntityId);

      // Assert — amounts are summed, not duplicated
      final captured = verify(() => repository.saveLines(2025, captureAny(), entityId: tEntityId))
          .captured
          .first as List<BudgetLine>;
      expect(captured, hasLength(2));
      expect(captured.any((l) => l.generalLedgerId == 'gl-1' && l.month == 1 && l.amountCents == 15000), isTrue);
      expect(captured.any((l) => l.generalLedgerId == 'gl-1' && l.month == 2 && l.amountCents == 28000), isTrue);
    });

    test('aggregates across different GL accounts independently', () async {
      // Arrange
      final row1 = ConfirmedImportRow(
        externalCode: 'A',
        externalName: 'A',
        generalLedgerId: 'gl-1',
        months: months(jan: 10000),
      );
      final row2 = ConfirmedImportRow(
        externalCode: 'B',
        externalName: 'B',
        generalLedgerId: 'gl-2',
        months: months(jan: 20000),
      );

      // Act
      await sut.execute(year: 2025, rows: [row1, row2], saveMappings: false, entityId: tEntityId);

      // Assert
      final captured = verify(() => repository.saveLines(2025, captureAny(), entityId: tEntityId))
          .captured
          .first as List<BudgetLine>;
      expect(captured, hasLength(2));
      expect(captured.any((l) => l.generalLedgerId == 'gl-1' && l.amountCents == 10000), isTrue);
      expect(captured.any((l) => l.generalLedgerId == 'gl-2' && l.amountCents == 20000), isTrue);
    });

    test('saves mappings when saveMappings is true', () async {
      // Arrange
      final row = ConfirmedImportRow(
        externalCode: 'MEMB',
        externalName: 'Memberships',
        generalLedgerId: 'gl-1',
        months: months(jan: 10000),
      );

      // Act
      await sut.execute(year: 2025, rows: [row], saveMappings: true, entityId: tEntityId);

      // Assert
      final captured = verify(() => repository.saveMappings(captureAny(), entityId: tEntityId))
          .captured
          .first as List<BudgetGlMapping>;
      expect(captured, hasLength(1));
      expect(captured.first.externalCode, 'MEMB');
      expect(captured.first.externalName, 'Memberships');
      expect(captured.first.generalLedgerId, 'gl-1');
      expect(captured.first.entityId, tEntityId);
    });

    test('does not save mappings when saveMappings is false', () async {
      // Arrange
      final row = ConfirmedImportRow(
        externalCode: 'MEMB',
        externalName: 'Memberships',
        generalLedgerId: 'gl-1',
        months: months(jan: 10000),
      );

      // Act
      await sut.execute(year: 2025, rows: [row], saveMappings: false, entityId: tEntityId);

      // Assert
      verifyNever(() => repository.saveMappings(any(), entityId: any(named: 'entityId')));
    });

    test('saves with empty lines when all month amounts are zero', () async {
      // Arrange
      final row = ConfirmedImportRow(
        externalCode: 'EMPTY',
        externalName: 'Empty',
        generalLedgerId: 'gl-1',
        months: List.filled(12, 0),
      );

      // Act
      await sut.execute(year: 2025, rows: [row], saveMappings: false, entityId: tEntityId);

      // Assert
      final captured = verify(() => repository.saveLines(2025, captureAny(), entityId: tEntityId))
          .captured
          .first as List<BudgetLine>;
      expect(captured, isEmpty);
    });

    test('passes correct year to repository', () async {
      // Arrange
      final row = ConfirmedImportRow(
        externalCode: 'MEMB',
        externalName: 'Memberships',
        generalLedgerId: 'gl-1',
        months: months(jun: 50000),
      );

      // Act
      await sut.execute(year: 2026, rows: [row], saveMappings: false, entityId: tEntityId);

      // Assert
      verify(() => repository.saveLines(2026, any(), entityId: tEntityId)).called(1);
    });
  });
}
