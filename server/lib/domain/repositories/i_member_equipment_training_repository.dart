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

import '../entities/member_equipment_training.dart';

/// Persistence contract for member equipment-training records.
abstract interface class IMemberEquipmentTrainingRepository {
  /// Returns the active equipment in the training Sections (Wood Shop and
  /// Metal Shop) for [entityId], ordered by section, description, asset no.
  Future<List<TrainingEquipment>> findEquipment({required String entityId});

  /// Returns every active training record for [entityId] (excluding those
  /// whose member or asset has been deleted), ordered by member then
  /// equipment description.
  Future<List<MemberEquipmentTraining>> findAll({required String entityId});

  /// Returns the active training records for [memberId] within [entityId].
  Future<List<MemberEquipmentTraining>> findForMember(
    String memberId, {
    required String entityId,
  });

  /// Makes [assetIds] the complete set of equipment [memberId] is trained
  /// on, atomically: assets not yet recorded are inserted dated
  /// [trainedOn], records for assets no longer listed are soft-deleted, and
  /// records already present keep their original date.
  ///
  /// Returns the member's resulting training records.
  Future<List<MemberEquipmentTraining>> replaceForMember({
    required String memberId,
    required String entityId,
    required Set<String> assetIds,
    required DateTime trainedOn,
  });
}
