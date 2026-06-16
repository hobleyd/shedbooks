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
