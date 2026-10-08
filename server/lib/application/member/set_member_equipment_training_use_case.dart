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

import '../../domain/entities/member.dart';
import '../../domain/entities/member_equipment_training.dart';
import '../../domain/exceptions/member_exception.dart';
import '../../domain/repositories/i_member_equipment_training_repository.dart';
import '../../domain/repositories/i_member_repository.dart';

/// Sets the complete list of equipment a member has been trained on.
class SetMemberEquipmentTrainingUseCase {
  final IMemberRepository _members;
  final IMemberEquipmentTrainingRepository _training;

  const SetMemberEquipmentTrainingUseCase(this._members, this._training);

  /// Makes [assetIds] the full set of equipment [memberId] is trained on.
  ///
  /// Newly listed equipment is recorded with [trainedOn]; equipment already
  /// recorded keeps its original date; equipment no longer listed is removed.
  ///
  /// Throws [MemberNotFoundException] if the member does not exist in
  /// [entityId], and [MemberValidationException] if any id is not Wood Shop
  /// / Metal Shop equipment belonging to [entityId] (equipment the member is
  /// already recorded against is always accepted).
  Future<List<MemberEquipmentTraining>> execute({
    required String memberId,
    required String entityId,
    required Set<String> assetIds,
    required DateTime trainedOn,
  }) async {
    final Member? member =
        await _members.findById(memberId, entityId: entityId);
    if (member == null) throw MemberNotFoundException(memberId);

    if (assetIds.isNotEmpty) {
      // Equipment the member is already recorded against stays valid even
      // if the asset has since been moved out of a training Section —
      // otherwise that one stale record would block every later save.
      final List<TrainingEquipment> equipment =
          await _training.findEquipment(entityId: entityId);
      final List<MemberEquipmentTraining> existing =
          await _training.findForMember(memberId, entityId: entityId);
      final Set<String> allowed = {
        ...equipment.map((TrainingEquipment e) => e.assetId),
        ...existing.map((MemberEquipmentTraining t) => t.equipment.assetId),
      };
      if (!allowed.containsAll(assetIds)) {
        throw const MemberValidationException(
          'Training can only be recorded against Wood Shop or Metal Shop '
          'equipment in the Asset register',
        );
      }
    }

    return _training.replaceForMember(
      memberId: memberId,
      entityId: entityId,
      assetIds: assetIds,
      trainedOn: DateTime.utc(trainedOn.year, trainedOn.month, trainedOn.day),
    );
  }
}
