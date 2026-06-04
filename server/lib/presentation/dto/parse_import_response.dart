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
