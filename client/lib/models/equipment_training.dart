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

/// Asset-register Section holding woodworking equipment.
const String kWoodShopSection = 'Wood Shop';

/// Asset-register Section holding metalworking equipment.
const String kMetalShopSection = 'Metal Shop';

/// A piece of Wood Shop / Metal Shop equipment from the Asset register that
/// a member can be trained on.
class TrainingEquipment {
  final String assetId;
  final String assetNo;

  /// The asset's Section as stored (e.g. "Wood Shop").
  final String section;
  final String? description;
  final String? brand;

  const TrainingEquipment({
    required this.assetId,
    required this.assetNo,
    required this.section,
    this.description,
    this.brand,
  });

  /// The name shown for this equipment: its description, falling back to
  /// the asset number when it has none.
  String get label {
    final String d = (description ?? '').trim();
    return d.isEmpty ? assetNo : d;
  }

  /// Whether this equipment belongs to [sectionName] (case-insensitive —
  /// the Section is free text in the Asset register).
  bool isInSection(String sectionName) =>
      section.trim().toLowerCase() == sectionName.toLowerCase();

  factory TrainingEquipment.fromJson(Map<String, dynamic> json) {
    return TrainingEquipment(
      assetId: json['assetId'] as String,
      assetNo: json['assetNo'] as String,
      section: json['section'] as String,
      description: json['description'] as String?,
      brand: json['brand'] as String?,
    );
  }
}

/// A record that a member has been trained on one piece of equipment.
class EquipmentTraining {
  final TrainingEquipment equipment;

  /// Date the training was recorded, in ISO 8601 date format (YYYY-MM-DD).
  final String trainedOn;

  const EquipmentTraining({required this.equipment, required this.trainedOn});

  factory EquipmentTraining.fromJson(Map<String, dynamic> json) {
    return EquipmentTraining(
      equipment: TrainingEquipment.fromJson(json),
      trainedOn: json['trainedOn'] as String,
    );
  }
}
