import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/budget_gl_mapping.dart';
import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/budget/parse_budget_import_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}
class MockGlRepository extends Mock implements IGeneralLedgerRepository {}

void main() {
  late MockBudgetRepository budgetRepo;
  late MockGlRepository glRepo;
  late ParseBudgetImportUseCase sut;

  const tEntityId = 'org-1';

  final tGlSales = GeneralLedger(
    id: 'gl-sales',
    label: 'Sales Revenue',
    description: 'Sales',
    gstApplicable: true,
    direction: GlDirection.moneyIn,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  final tGlWages = GeneralLedger(
    id: 'gl-wages',
    label: 'Wages',
    description: 'Wages',
    gstApplicable: false,
    direction: GlDirection.moneyOut,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  final tGlMemberships = GeneralLedger(
    id: 'gl-memberships',
    label: 'Memberships',
    description: 'Memberships',
    gstApplicable: true,
    direction: GlDirection.moneyIn,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  final tGlRent = GeneralLedger(
    id: 'gl-rent',
    label: 'Rent',
    description: 'Rent',
    gstApplicable: false,
    direction: GlDirection.moneyOut,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  final tGlRecycling = GeneralLedger(
    id: 'gl-recycling',
    label: 'Recycling',
    description: 'Recycling',
    gstApplicable: true,
    direction: GlDirection.moneyIn,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  setUp(() {
    budgetRepo = MockBudgetRepository();
    glRepo = MockGlRepository();
    sut = ParseBudgetImportUseCase(budgetRepo, glRepo);

    when(() => budgetRepo.getMappings(entityId: tEntityId))
        .thenAnswer((_) async => []);
    when(() => glRepo.findAll(entityId: tEntityId))
        .thenAnswer((_) async => [tGlSales, tGlWages, tGlMemberships, tGlRent, tGlRecycling]);
  });

  group('ParseBudgetImportUseCase', () {
    test('parses monthly-column CSV correctly', () async {
      // Arrange
      const csv = 'Code,Name,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec\n'
          '4000,Sales Revenue,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert
      expect(rows, hasLength(1));
      expect(rows[0].externalCode, '4000');
      expect(rows[0].externalName, 'Sales Revenue');
      expect(rows[0].months, hasLength(12));
      expect(rows[0].months[0], 100000); // $1000 = 100000 cents
    });

    test('parses annual-total CSV and spreads across months', () async {
      // Arrange
      const csv = 'Code,Name,Annual\n5000,Wages,120000\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert
      expect(rows, hasLength(1));
      expect(rows[0].months.fold<int>(0, (s, v) => s + v), 12000000);
    });

    test('uses saved mapping as exact match with confidence 1.0', () async {
      // Arrange
      when(() => budgetRepo.getMappings(entityId: tEntityId))
          .thenAnswer((_) async => [
                const BudgetGlMapping(
                  entityId: tEntityId,
                  externalCode: '4000',
                  externalName: 'Old Sales',
                  generalLedgerId: 'gl-sales',
                ),
              ]);

      const csv = 'Code,Name,Annual\n4000,Old Sales,60000\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert
      expect(rows[0].suggestedGlId, 'gl-sales');
      expect(rows[0].confidence, 1.0);
    });

    test('prefers leaf segment over parent segment when both score equally', () async {
      // Arrange: GL has "Sales" (parent) and "Recycling" (child) both as moneyIn.
      // CSV description "Sales - Recycling" would match both with score 1.0 via segments.
      // The leaf "Recycling" must win the tie.
      when(() => glRepo.findAll(entityId: tEntityId)).thenAnswer((_) async => [
            tGlSales,     // description "Sales"   — matches parent segment
            tGlRecycling, // description "Recycling" — matches leaf segment
          ]);

      const csv = 'Code,Name,Annual\n4000,Sales - Recycling,12000\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert: leaf "Recycling" beats parent "Sales" on the tie
      expect(rows[0].suggestedGlId, 'gl-recycling');
    });

    test('returns null suggestion for unrecognised account name', () async {
      // Arrange
      const csv = 'Code,Name,Annual\nXX99,Completely Unknown Account XYZ,10000\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert
      expect(rows[0].suggestedGlId, isNull);
    });

    test('returns empty list for empty CSV', () async {
      // Act
      final rows = await sut.execute(csvContent: '', entityId: tEntityId);
      expect(rows, isEmpty);
    });

    test('parses dollar amounts with currency symbols and commas', () async {
      // Arrange
      const csv = 'Code,Name,Annual\n4000,Sales,"\$1,200.00"\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert
      expect(rows[0].months.fold<int>(0, (s, v) => s + v), 120000); // $1200 total
    });
  });

  group('ParseBudgetImportUseCase — sectioned CSV format', () {
    // Reproduces the real legacy export: year-prefixed month headers,
    // Money In / Money Out section blocks, skip rows, all-zero rows, whole dollars.
    const sectionedCsv = ''
        ',2026 Jan,2026 Feb,2026 Mar,2026 Apr,2026 May,2026 Jun,'
        '2026 Jul,2026 Aug,2026 Sept,2026 Oct,2026 Nov,2026 Dec\n'
        'Money In\n'
        'Sales,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000\n'
        'Memberships,500,500,500,500,500,500,500,500,500,500,500,500\n'
        'Unused Income,0,0,0,0,0,0,0,0,0,0,0,0\n'
        'Total Money In,1500,1500,1500,1500,1500,1500,1500,1500,1500,1500,1500,1500\n'
        'Money Out\n'
        'Wages,800,800,800,800,800,800,800,800,800,800,800,800\n'
        'Rent,200,200,200,200,200,200,200,200,200,200,200,200\n'
        'Total Money Out,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000\n'
        'Net,500,500,500,500,500,500,500,500,500,500,500,500\n'
        'OPENING CASH,5000,5500,6000,6500,7000,7500,8000,8500,9000,9500,10000,10500\n'
        'CASH BALANCE,5500,6000,6500,7000,7500,8000,8500,9000,9500,10000,10500,11000\n';

    test('returns one row per non-skip non-zero data row', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert: Sales, Memberships (Money In) + Wages, Rent (Money Out) = 4 rows
      expect(rows, hasLength(4));
    });

    test('assigns correct direction to each row', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert
      final moneyInRows = rows.where((r) => r.direction == 'moneyIn').toList();
      final moneyOutRows = rows.where((r) => r.direction == 'moneyOut').toList();
      expect(moneyInRows, hasLength(2));
      expect(moneyOutRows, hasLength(2));
    });

    test('parses year-prefixed month headers including Sept', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert: Sales = $1000/month → 100000 cents each; all 12 months populated
      final salesRow = rows.firstWhere((r) => r.externalCode == 'Sales');
      expect(salesRow.months, hasLength(12));
      expect(salesRow.months[8], 100000); // index 8 = September
      expect(salesRow.months.every((v) => v == 100000), isTrue);
    });

    test('converts whole-dollar values to cents', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert: Memberships = $500/month = 50000 cents
      final membershipsRow = rows.firstWhere((r) => r.externalCode == 'Memberships');
      expect(membershipsRow.months[0], 50000);
    });

    test('skips Total, Net, Opening Cash, Cash Balance rows', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert: none of the skip rows appear in results
      final descriptions = rows.map((r) => r.externalCode).toSet();
      expect(descriptions, isNot(contains('Total Money In')));
      expect(descriptions, isNot(contains('Total Money Out')));
      expect(descriptions, isNot(contains('Net')));
      expect(descriptions, isNot(contains('OPENING CASH')));
      expect(descriptions, isNot(contains('CASH BALANCE')));
    });

    test('skips all-zero rows', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert: "Unused Income" (all zeros) is not present
      expect(rows.any((r) => r.externalCode == 'Unused Income'), isFalse);
    });

    test('restricts GL matching to correct direction', () async {
      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert: Wages (moneyOut) must not be matched to a moneyIn GL
      final wagesRow = rows.firstWhere((r) => r.externalCode == 'Wages');
      expect(wagesRow.direction, 'moneyOut');
      // gl-sales and gl-memberships are moneyIn — Wages should not be matched to them
      expect(wagesRow.suggestedGlId, isNot('gl-sales'));
      expect(wagesRow.suggestedGlId, isNot('gl-memberships'));
    });

    test('matches leaf segment of hierarchical CSV description to specific GL account', () async {
      // Arrange: CSV has "Fundraising - Recycling"; GL has both a parent "Fundraising"
      // account (gl-sales repurposed here) and a child "Recycling" account (gl-recycling).
      // Both would score 1.0 via segment matching — the leaf ("Recycling") must win.
      const csv = ''
          ',2026 Jan,2026 Feb,2026 Mar,2026 Apr,2026 May,2026 Jun,'
          '2026 Jul,2026 Aug,2026 Sept,2026 Oct,2026 Nov,2026 Dec\n'
          'Money In\n'
          'Fundraising - Recycling,100,100,100,100,100,100,100,100,100,100,100,100\n';

      // Act
      final rows = await sut.execute(csvContent: csv, entityId: tEntityId);

      // Assert: leaf segment "Recycling" must beat parent segment "Sales" on a tie
      expect(rows, hasLength(1));
      expect(rows[0].suggestedGlId, 'gl-recycling');
      expect(rows[0].confidence, greaterThan(0.8));
    });

    test('uses saved mapping for sectioned format row', () async {
      // Arrange
      when(() => budgetRepo.getMappings(entityId: tEntityId))
          .thenAnswer((_) async => [
                const BudgetGlMapping(
                  entityId: tEntityId,
                  externalCode: 'Sales',
                  externalName: 'Sales',
                  generalLedgerId: 'gl-sales',
                ),
              ]);

      // Act
      final rows = await sut.execute(csvContent: sectionedCsv, entityId: tEntityId);

      // Assert
      final salesRow = rows.firstWhere((r) => r.externalCode == 'Sales');
      expect(salesRow.suggestedGlId, 'gl-sales');
      expect(salesRow.confidence, 1.0);
    });
  });
}
