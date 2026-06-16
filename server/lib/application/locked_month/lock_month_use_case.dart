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

import '../../domain/repositories/i_locked_month_repository.dart';

/// Locks a month so that no transactions in that period may be modified.
class LockMonthUseCase {
  final ILockedMonthRepository _repository;

  const LockMonthUseCase(this._repository);

  /// Locks [monthYear] (YYYY-MM format) for [bankAccountId] within [entityId]. Idempotent.
  Future<void> execute(
      String entityId, String monthYear, String bankAccountId) {
    _validateFormat(monthYear);
    return _repository.lock(entityId, monthYear, bankAccountId);
  }

  static void _validateFormat(String monthYear) {
    final re = RegExp(r'^\d{4}-(?:0[1-9]|1[0-2])$');
    if (!re.hasMatch(monthYear)) {
      throw ArgumentError('monthYear must be in YYYY-MM format, got: $monthYear');
    }
  }
}
