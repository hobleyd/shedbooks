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

/// Lists the Wood Shop / Metal Shop equipment members can be trained on.
class ListTrainingEquipmentUseCase {
  final IMemberEquipmentTrainingRepository _repository;

  const ListTrainingEquipmentUseCase(this._repository);

  /// Returns the trainable equipment for [entityId].
  Future<List<TrainingEquipment>> execute({required String entityId}) =>
      _repository.findEquipment(entityId: entityId);
}
