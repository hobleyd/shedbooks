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

import '../../domain/entities/member_equipment_training.dart';

/// Response DTO for one piece of trainable equipment
/// (`GET /members/training-equipment`).
class TrainingEquipmentResponse {
  /// Serialises [e] to its JSON map.
  static Map<String, dynamic> toJson(TrainingEquipment e) => {
        'assetId': e.assetId,
        'assetNo': e.assetNo,
        'section': e.section,
        'description': e.description,
        'brand': e.brand,
      };
}

/// Response DTO for one member equipment-training record.
class MemberEquipmentTrainingResponse {
  /// Serialises [t] to its JSON map — the equipment fields plus
  /// `trainedOn` as `YYYY-MM-DD`.
  static Map<String, dynamic> toJson(MemberEquipmentTraining t) => {
        ...TrainingEquipmentResponse.toJson(t.equipment),
        'trainedOn': t.trainedOn.toIso8601String().substring(0, 10),
      };

  /// Serialises a list of records.
  static List<Map<String, dynamic>> listToJson(
    List<MemberEquipmentTraining> training,
  ) =>
      training.map(toJson).toList();
}
