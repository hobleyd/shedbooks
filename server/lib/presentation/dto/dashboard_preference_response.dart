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

import 'dart:convert';

import '../../domain/entities/dashboard_preference.dart';

/// Response DTO for dashboard preferences.
class DashboardPreferenceResponse {
  final List<GlAccountPair> selectedAccountPairs;

  const DashboardPreferenceResponse({required this.selectedAccountPairs});

  factory DashboardPreferenceResponse.fromEntity(DashboardPreference e) =>
      DashboardPreferenceResponse(selectedAccountPairs: e.selectedAccountPairs);

  Map<String, dynamic> toJson() => {
        'selectedAccountPairs': selectedAccountPairs
            .map((p) =>
                {'incomeGlId': p.incomeGlId, 'expenseGlId': p.expenseGlId})
            .toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}
