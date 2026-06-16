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

import '../../domain/entities/dashboard_preference.dart';
import '../../domain/repositories/i_dashboard_preference_repository.dart';

/// Returns the dashboard GL account pair selections for an entity.
/// When no preference has been saved, returns an empty preference.
class GetDashboardPreferenceUseCase {
  final IDashboardPreferenceRepository _repository;

  const GetDashboardPreferenceUseCase(this._repository);

  Future<DashboardPreference> execute(String entityId) async {
    return await _repository.find(entityId) ??
        DashboardPreference(entityId: entityId, selectedAccountPairs: const []);
  }
}
