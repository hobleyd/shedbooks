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
