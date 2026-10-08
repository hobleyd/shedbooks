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

/// The Asset-register Sections whose equipment members are trained on.
///
/// Values match `assets.asset_type` case-insensitively (the Section is free
/// text, originally a spreadsheet sheet name).
enum TrainingSection {
  /// Woodworking equipment — the "Wood Shop" Section.
  woodShop('Wood Shop'),

  /// Metalworking equipment — the "Metal Shop" Section.
  metalShop('Metal Shop');

  /// The Section name as it appears in the Asset register.
  final String sectionName;

  const TrainingSection(this.sectionName);

  /// Returns the section matching [assetType] (case-insensitive, trimmed),
  /// or null if [assetType] is not a training section.
  static TrainingSection? fromAssetType(String assetType) {
    final String needle = assetType.trim().toLowerCase();
    for (final TrainingSection s in values) {
      if (s.sectionName.toLowerCase() == needle) return s;
    }
    return null;
  }
}

/// A piece of equipment from the Asset register that a member can be
/// trained on.
class TrainingEquipment {
  /// The asset's unique identifier (UUID v4).
  final String assetId;

  /// The asset number (e.g. `2026-W-0001`).
  final String assetNo;

  /// The asset's Section as stored (e.g. `Wood Shop`).
  final String section;

  /// The asset's description, if any.
  final String? description;

  /// The asset's brand, if any.
  final String? brand;

  const TrainingEquipment({
    required this.assetId,
    required this.assetNo,
    required this.section,
    this.description,
    this.brand,
  });
}

/// A record that a member has been trained on one piece of equipment.
class MemberEquipmentTraining {
  /// The trained member's identifier.
  final String memberId;

  /// The equipment the member was trained on.
  final TrainingEquipment equipment;

  /// The date the training was recorded.
  final DateTime trainedOn;

  const MemberEquipmentTraining({
    required this.memberId,
    required this.equipment,
    required this.trainedOn,
  });
}
