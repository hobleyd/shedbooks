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

import '../../application/budget/confirm_budget_import_use_case.dart';

/// Parsed request body for POST /budgets/<year>/confirm-import.
class ConfirmImportRequest {
  final List<ConfirmedImportRow> rows;
  final bool saveMappings;

  const ConfirmImportRequest({
    required this.rows,
    required this.saveMappings,
  });

  factory ConfirmImportRequest.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'];
    if (rawRows is! List) throw const FormatException('rows must be an array');

    final rows = <ConfirmedImportRow>[];
    for (final raw in rawRows) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Each row must be an object');
      }
      final glId = raw['generalLedgerId'];
      if (glId is! String || glId.isEmpty) {
        throw const FormatException('generalLedgerId must be a non-empty string');
      }
      final code = raw['externalCode'] as String? ?? '';
      final name = raw['externalName'] as String? ?? '';
      final months = raw['months'];
      if (months is! List || months.length != 12) {
        throw const FormatException('months must be a 12-element array');
      }
      final monthCents = List<int>.generate(12, (i) {
        final v = months[i];
        if (v is! int || v < 0) {
          throw const FormatException('Each month value must be a non-negative integer');
        }
        return v;
      });
      rows.add(ConfirmedImportRow(
        externalCode: code,
        externalName: name,
        generalLedgerId: glId,
        months: monthCents,
      ));
    }

    final saveMappings = json['saveMappings'] as bool? ?? false;
    return ConfirmImportRequest(rows: rows, saveMappings: saveMappings);
  }
}
