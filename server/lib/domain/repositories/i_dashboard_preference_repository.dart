import '../entities/dashboard_preference.dart';

/// Repository interface for dashboard preference persistence.
abstract class IDashboardPreferenceRepository {
  /// Returns the preference for [entityId], or null if none has been saved.
  Future<DashboardPreference?> find(String entityId);

  /// Upserts the preference for the entity it belongs to.
  Future<void> save(DashboardPreference preference);
}
