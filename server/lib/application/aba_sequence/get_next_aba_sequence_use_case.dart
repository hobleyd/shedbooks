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

import '../../domain/repositories/i_aba_sequence_repository.dart';

/// Returns the next daily ABA file sequence number for an entity.
class GetNextAbaSequenceUseCase {
  final IAbaSequenceRepository _repository;

  const GetNextAbaSequenceUseCase(this._repository);

  /// Returns the next sequence number (1-based) for [entityId] on today's date.
  Future<int> execute(String entityId) => _repository.nextSequence(entityId);
}
