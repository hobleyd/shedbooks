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
import '../../domain/repositories/i_member_equipment_training_repository.dart';

/// Lists equipment-training records, per entity or per member.
class ListMemberEquipmentTrainingUseCase {
  final IMemberEquipmentTrainingRepository _repository;

  const ListMemberEquipmentTrainingUseCase(this._repository);

  /// Returns every active training record for [entityId], grouped by
  /// member id. Members with no training have no key.
  Future<Map<String, List<MemberEquipmentTraining>>> execute({
    required String entityId,
  }) async {
    final List<MemberEquipmentTraining> all =
        await _repository.findAll(entityId: entityId);
    final Map<String, List<MemberEquipmentTraining>> byMember = {};
    for (final MemberEquipmentTraining t in all) {
      byMember.putIfAbsent(t.memberId, () => []).add(t);
    }
    return byMember;
  }

  /// Returns the active training records for [memberId] within [entityId].
  Future<List<MemberEquipmentTraining>> executeForMember(
    String memberId, {
    required String entityId,
  }) =>
      _repository.findForMember(memberId, entityId: entityId);
}
