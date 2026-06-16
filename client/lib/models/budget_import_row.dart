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

import 'general_ledger_entry.dart';

/// A single row returned by the server after parsing a budget CSV.
///
/// [selectedGlId] is mutable — set by the user in the mapping UI.
class BudgetImportRow {
  final String externalCode;
  final String externalName;
  final String? suggestedGlId;
  final String? suggestedGlLabel;

  /// 12-element list in cents; index 0 = January.
  final List<int> months;
  final double confidence;

  /// 'moneyIn' or 'moneyOut' — the CSV section this row came from.
  final GlDirection direction;

  /// User-selected GL account ID (defaults to [suggestedGlId]).
  String? selectedGlId;

  BudgetImportRow({
    required this.externalCode,
    required this.externalName,
    required this.suggestedGlId,
    required this.suggestedGlLabel,
    required this.months,
    required this.confidence,
    required this.direction,
  }) : selectedGlId = suggestedGlId;

  factory BudgetImportRow.fromJson(Map<String, dynamic> json) {
    final dirStr = json['direction'] as String? ?? 'moneyOut';
    return BudgetImportRow(
      externalCode: json['externalCode'] as String? ?? '',
      externalName: json['externalName'] as String? ?? '',
      suggestedGlId: json['suggestedGlId'] as String?,
      suggestedGlLabel: json['suggestedGlLabel'] as String?,
      months: (json['months'] as List? ?? List.filled(12, 0))
          .map((v) => v as int)
          .toList(),
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
      direction: dirStr == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
    );
  }

  int get annualTotal => months.fold<int>(0, (s, v) => s + v);
}
