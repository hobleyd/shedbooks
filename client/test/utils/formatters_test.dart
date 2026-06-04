import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/utils/formatters.dart';

void main() {
  group('Formatters.formatCents', () {
    test('zero', () {
      expect(Formatters.formatCents(0), equals(r'$0.00'));
    });

    test('positive sub-1000', () {
      expect(Formatters.formatCents(28900), equals(r'$289.00'));
    });

    test('positive with thousands separator', () {
      expect(Formatters.formatCents(123456789), equals(r'$1,234,567.89'));
    });

    test('exactly 1000 dollars', () {
      expect(Formatters.formatCents(100000), equals(r'$1,000.00'));
    });

    test('negative sub-1000 has no spurious comma', () {
      expect(Formatters.formatCents(-28900), equals(r'$-289.00'));
    });

    test('negative sub-1000 boundary (-999.99)', () {
      expect(Formatters.formatCents(-99999), equals(r'$-999.99'));
    });

    test('negative with thousands separator', () {
      expect(Formatters.formatCents(-123456789), equals(r'$-1,234,567.89'));
    });

    test('negative exactly -1000 dollars', () {
      expect(Formatters.formatCents(-100000), equals(r'$-1,000.00'));
    });

    test('cents only', () {
      expect(Formatters.formatCents(42), equals(r'$0.42'));
    });
  });

  group('Formatters.budgetPctLabel', () {
    test('returns empty string when budget is zero', () {
      expect(Formatters.budgetPctLabel(0, 5000), equals(''));
    });

    test('normal positive — actual equals budget gives 100%', () {
      expect(Formatters.budgetPctLabel(10000, 10000), equals('100%'));
    });

    test('actual exceeds budget — shows plain percentage', () {
      expect(Formatters.budgetPctLabel(10000, 15000), equals('150%'));
    });

    test('actual below budget — wrapped in parens', () {
      expect(Formatters.budgetPctLabel(10000, 5000), equals('(50%)'));
    });

    test('actual zero — wrapped in parens showing 0%', () {
      expect(Formatters.budgetPctLabel(10000, 0), equals('(0%)'));
    });

    test('percentage above 999 — shows >999%', () {
      expect(Formatters.budgetPctLabel(2300, 64609), equals('>999%'));
    });

    test('percentage exactly 999 — shows 999% (not capped)', () {
      // 99900 / 10000 * 100 = 999%
      expect(Formatters.budgetPctLabel(10000, 99900), equals('999%'));
    });

    test('percentage just over 999 — shows >999%', () {
      // 100100 / 10000 * 100 = 1001%
      expect(Formatters.budgetPctLabel(10000, 100100), equals('>999%'));
    });
  });
}
