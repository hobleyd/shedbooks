import 'dart:convert';

import '../../domain/entities/dashboard_preference.dart';

/// Response DTO for dashboard preferences.
class DashboardPreferenceResponse {
  final List<String> selectedGlIds;

  const DashboardPreferenceResponse({required this.selectedGlIds});

  factory DashboardPreferenceResponse.fromEntity(DashboardPreference e) =>
      DashboardPreferenceResponse(selectedGlIds: e.selectedGlIds);

  Map<String, dynamic> toJson() => {'selectedGlIds': selectedGlIds};

  String toJsonString() => jsonEncode(toJson());
}
