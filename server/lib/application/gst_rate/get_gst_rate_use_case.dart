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
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Retrieves a single GST rate by ID.
class GetGstRateUseCase {
  final IGstRateRepository _repository;

  const GetGstRateUseCase(this._repository);

  Future<GstRate> execute(String id, {required String entityId}) async {
    final rate = await _repository.findById(id, entityId: entityId);
    if (rate == null) throw GstRateNotFoundException(id);
    return rate;
  }
}
