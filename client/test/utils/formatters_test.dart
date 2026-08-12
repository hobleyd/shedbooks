// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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

    test('normal positive — actual equals budget gives 0% variance', () {
      expect(Formatters.budgetPctLabel(10000, 10000), equals('0%'));
    });

    test('actual exceeds budget — shows plain percentage over', () {
      // (15000 - 10000) / 10000 * 100 = 50%
      expect(Formatters.budgetPctLabel(10000, 15000), equals('50%'));
    });

    test('actual below budget — wrapped in parens', () {
      // (5000 - 10000) / 10000 * 100 = -50%, abs = 50%
      expect(Formatters.budgetPctLabel(10000, 5000), equals('(50%)'));
    });

    test('actual zero — wrapped in parens showing 100% variance', () {
      // (0 - 10000) / 10000 * 100 = -100%, abs = 100%
      expect(Formatters.budgetPctLabel(10000, 0), equals('(100%)'));
    });

    test('percentage above 999 — shows >999%', () {
      // (64609 - 2300) / 2300 * 100 = 2709% (approx)
      expect(Formatters.budgetPctLabel(2300, 64609), equals('>999%'));
    });

    test('percentage exactly 999 — shows 999% (not capped)', () {
      // (109900 - 10000) / 10000 * 100 = 999%
      expect(Formatters.budgetPctLabel(10000, 109900), equals('999%'));
    });

    test('percentage just over 999 — shows >999%', () {
      // (110000 - 10000) / 10000 * 100 = 1000%
      expect(Formatters.budgetPctLabel(10000, 110000), equals('>999%'));
    });
  });
}
