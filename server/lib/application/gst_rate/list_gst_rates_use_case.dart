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

import '../../domain/entities/gst_rate.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Returns all active GST rates for an entity ordered by effectiveFrom descending.
class ListGstRatesUseCase {
  final IGstRateRepository _repository;

  const ListGstRatesUseCase(this._repository);

  Future<List<GstRate>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
