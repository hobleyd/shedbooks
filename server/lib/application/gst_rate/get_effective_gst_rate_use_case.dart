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

/// Returns the GST rate effective at a given point in time.
class GetEffectiveGstRateUseCase {
  final IGstRateRepository _repository;

  const GetEffectiveGstRateUseCase(this._repository);

  Future<GstRate> execute({required String entityId, DateTime? date}) async {
    final target = date ?? DateTime.now().toUtc();
    final rate = await _repository.findEffectiveAt(target, entityId: entityId);
    if (rate == null) throw GstRateNotEffectiveException(target);
    return rate;
  }
}
