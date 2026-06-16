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
import '../../domain/entities/general_ledger.dart';

/// JSON response shape for a general ledger account.
class GeneralLedgerResponse {
  final String id;
  final String label;
  final String description;
  final bool gstApplicable;
  final String direction;
  final String createdAt;
  final String updatedAt;
  final String? parentId;

  const GeneralLedgerResponse({
    required this.id,
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  factory GeneralLedgerResponse.fromEntity(GeneralLedger entity) {
    return GeneralLedgerResponse(
      id: entity.id,
      label: entity.label,
      description: entity.description,
      gstApplicable: entity.gstApplicable,
      direction: entity.direction == GlDirection.moneyIn ? 'moneyIn' : 'moneyOut',
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
      parentId: entity.parentId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'gstApplicable': gstApplicable,
        'direction': direction,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'parentId': parentId,
      };

  String toJsonString() => jsonEncode(toJson());
}
