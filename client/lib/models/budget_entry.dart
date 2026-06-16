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

/// A full budget for one calendar year, keyed by GL account ID.
///
/// [lines] maps generalLedgerId → 12-element list of monthly amounts in cents
/// (index 0 = January, index 11 = December).
class BudgetEntry {
  final int year;
  final Map<String, List<int>> lines;

  const BudgetEntry({required this.year, required this.lines});

  factory BudgetEntry.fromJson(Map<String, dynamic> json) {
    final lines = <String, List<int>>{};
    for (final raw in (json['lines'] as List? ?? [])) {
      final glId = raw['generalLedgerId'] as String;
      final months = (raw['months'] as List).map((v) => v as int).toList();
      lines[glId] = months;
    }
    return BudgetEntry(year: json['year'] as int, lines: lines);
  }

  Map<String, dynamic> toJson() => {
        'year': year,
        'lines': lines.entries
            .map((e) => {'generalLedgerId': e.key, 'months': e.value})
            .toList(),
      };

  /// Returns the budgeted amount for [glId] in [month] (1-based), or 0.
  int amountFor(String glId, int month) {
    final months = lines[glId];
    if (months == null || month < 1 || month > 12) return 0;
    return months[month - 1];
  }

  /// Returns the total annual budget for [glId].
  int annualFor(String glId) {
    final months = lines[glId];
    if (months == null) return 0;
    return months.fold<int>(0, (s, v) => s + v);
  }
}
