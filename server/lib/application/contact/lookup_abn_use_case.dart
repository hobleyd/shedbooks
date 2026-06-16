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

import '../../infrastructure/services/abn_lookup_service.dart';

export '../../infrastructure/services/abn_lookup_service.dart' show AbnLookupResult;

/// Resolves an ABN against the Australian Business Register.
class LookupAbnUseCase {
  final AbnLookupService _service;

  const LookupAbnUseCase(this._service);

  /// Looks up [abn] (must be exactly 11 digits).
  Future<AbnLookupResult> execute(String abn) {
    return _service.lookup(abn);
  }
}
