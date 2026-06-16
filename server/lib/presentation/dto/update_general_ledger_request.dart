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

import '../../domain/entities/general_ledger.dart';

/// Deserialised request body for PUT /general-ledger/:id.
class UpdateGeneralLedgerRequest {
  final String label;
  final String description;
  final bool gstApplicable;
  final GlDirection direction;
  final String? parentId;

  const UpdateGeneralLedgerRequest({
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    this.parentId,
  });

  factory UpdateGeneralLedgerRequest.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final description = json['description'];
    final gstApplicable = json['gstApplicable'];
    final direction = json['direction'];
    final parentId = json['parentId'];

    if (label is! String) throw FormatException('label must be a string');
    if (description is! String) throw FormatException('description must be a string');
    if (gstApplicable is! bool) throw FormatException('gstApplicable must be a boolean');
    if (direction is! String || (direction != 'moneyIn' && direction != 'moneyOut')) {
      throw FormatException('direction must be "moneyIn" or "moneyOut"');
    }
    if (parentId != null && parentId is! String) {
      throw FormatException('parentId must be a string or null');
    }

    return UpdateGeneralLedgerRequest(
      label: label,
      description: description,
      gstApplicable: gstApplicable,
      direction: direction == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
      parentId: parentId as String?,
    );
  }
}
