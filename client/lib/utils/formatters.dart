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

class Formatters {
  static String formatCents(int cents) {
    final formatted = (cents / 100).toStringAsFixed(2);
    final negative = formatted.startsWith('-');
    final parts = (negative ? formatted.substring(1) : formatted).split('.');
    final buf = StringBuffer();
    int c = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
      c++;
    }
    final intPart = buf.toString().split('').reversed.join();
    return '\$${negative ? '-' : ''}$intPart.${parts[1]}';
  }

  /// Returns the budget percentage label for [actual] vs [budget] (both cents).
  ///
  /// Returns '' when [budget] is zero. Values above 999% show as '>999%'.
  /// When [actual] < [budget] the result is wrapped in parentheses.
  static String budgetPctLabel(int budget, int actual) {
    if (budget == 0) return '';
    final pct = ((actual - budget) / budget * 100).abs();
    final raw = pct > 999 ? '>999%' : '${pct.toStringAsFixed(0)}%';
    return actual < budget ? '($raw)' : raw;
  }

  static String formatAbn(String abn) {
    final d = abn.replaceAll(' ', '');
    if (d.length != 11) return abn;
    return '${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 8)} ${d.substring(8)}';
  }

  static String formatDateShort(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
