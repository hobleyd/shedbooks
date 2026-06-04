import 'dart:convert';
import '../../domain/entities/budget_gl_mapping.dart';

/// JSON response for GET /budgets/gl-mappings.
class BudgetGlMappingsResponse {
  final List<BudgetGlMapping> mappings;

  const BudgetGlMappingsResponse({required this.mappings});

  Map<String, dynamic> toJson() => {
        'mappings': mappings
            .map((m) => {
                  'externalCode': m.externalCode,
                  'externalName': m.externalName,
                  'generalLedgerId': m.generalLedgerId,
                })
            .toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}
