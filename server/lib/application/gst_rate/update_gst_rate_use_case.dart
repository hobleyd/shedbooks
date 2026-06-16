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

/// Updates an existing GST rate.
class UpdateGstRateUseCase {
  final IGstRateRepository _repository;

  const UpdateGstRateUseCase(this._repository);

  Future<GstRate> execute({
    required String id,
    required String entityId,
    required double rate,
    required DateTime effectiveFrom,
  }) async {
    if (rate < 0 || rate > 1) {
      throw const GstRateValidationException(
        'Rate must be between 0 and 1 (e.g. 0.10 for 10%)',
      );
    }

    return _repository.update(id: id, entityId: entityId, rate: rate, effectiveFrom: effectiveFrom);
  }
}
