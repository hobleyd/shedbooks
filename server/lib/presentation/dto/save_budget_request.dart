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

import '../../domain/entities/budget_line.dart';

/// Parsed request body for PUT /budgets/<year>.
class SaveBudgetRequest {
  final List<BudgetLine> lines;

  const SaveBudgetRequest({required this.lines});

  factory SaveBudgetRequest.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const FormatException('lines must be an array');
    }

    final lines = <BudgetLine>[];
    for (final raw in rawLines) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Each line must be an object');
      }
      final glId = raw['generalLedgerId'];
      if (glId is! String || glId.isEmpty) {
        throw const FormatException('generalLedgerId must be a non-empty string');
      }
      final months = raw['months'];
      if (months is! List || months.length != 12) {
        throw const FormatException('months must be a 12-element array');
      }
      for (int m = 0; m < 12; m++) {
        final cents = months[m];
        if (cents is! int || cents < 0) {
          throw const FormatException('Each month value must be a non-negative integer (cents)');
        }
        if (cents > 0) {
          lines.add(BudgetLine(
            generalLedgerId: glId,
            month: m + 1,
            amountCents: cents,
          ));
        }
      }
    }

    return SaveBudgetRequest(lines: lines);
  }
}
