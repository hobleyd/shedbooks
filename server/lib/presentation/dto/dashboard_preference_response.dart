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
