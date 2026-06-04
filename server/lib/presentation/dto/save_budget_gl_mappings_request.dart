import '../../domain/entities/budget_gl_mapping.dart';

/// Parsed request body for PUT /budgets/gl-mappings.
class SaveBudgetGlMappingsRequest {
  final List<BudgetGlMapping> mappings;

  const SaveBudgetGlMappingsRequest({required this.mappings});

  factory SaveBudgetGlMappingsRequest.fromJson(
    Map<String, dynamic> json,
    String entityId,
  ) {
    final rawMappings = json['mappings'];
    if (rawMappings is! List) {
      throw const FormatException('mappings must be an array');
    }
    final mappings = rawMappings.map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Each mapping must be an object');
      }
      final code = raw['externalCode'];
      if (code is! String || code.isEmpty) {
        throw const FormatException('externalCode must be a non-empty string');
      }
      final glId = raw['generalLedgerId'];
      if (glId is! String || glId.isEmpty) {
        throw const FormatException('generalLedgerId must be a non-empty string');
      }
      return BudgetGlMapping(
        entityId: entityId,
        externalCode: code,
        externalName: raw['externalName'] as String? ?? '',
        generalLedgerId: glId,
      );
    }).toList();

    return SaveBudgetGlMappingsRequest(mappings: mappings);
  }
}
