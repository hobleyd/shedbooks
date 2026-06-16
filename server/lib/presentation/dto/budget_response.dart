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

import 'dart:convert';
import '../../domain/entities/budget_line.dart';

/// JSON response for a budget year: groups lines by GL account into a
/// 12-element months array (index 0 = January).
class BudgetResponse {
  final int year;
  final List<Map<String, dynamic>> lines;

  const BudgetResponse({required this.year, required this.lines});

  factory BudgetResponse.fromLines(int year, List<BudgetLine> dbLines) {
    // Group by GL account.
    final Map<String, List<int>> grouped = {};
    for (final line in dbLines) {
      grouped[line.generalLedgerId] ??= List<int>.filled(12, 0);
      if (line.month >= 1 && line.month <= 12) {
        grouped[line.generalLedgerId]![line.month - 1] = line.amountCents;
      }
    }

    final lines = grouped.entries
        .map((e) => {
              'generalLedgerId': e.key,
              'months': e.value,
            })
        .toList();

    return BudgetResponse(year: year, lines: lines);
  }

  Map<String, dynamic> toJson() => {'year': year, 'lines': lines};
  String toJsonString() => jsonEncode(toJson());
}
