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
