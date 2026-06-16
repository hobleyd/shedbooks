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
import '../../application/budget/parse_budget_import_use_case.dart';

/// JSON response for POST /budgets/parse-import.
class ParseImportResponse {
  final List<ParsedImportRow> rows;

  const ParseImportResponse({required this.rows});

  Map<String, dynamic> toJson() => {
        'rows': rows
            .map((r) => {
                  'externalCode': r.externalCode,
                  'externalName': r.externalName,
                  'suggestedGlId': r.suggestedGlId,
                  'suggestedGlLabel': r.suggestedGlLabel,
                  'months': r.months,
                  'confidence': r.confidence,
                  'direction': r.direction,
                })
            .toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}
