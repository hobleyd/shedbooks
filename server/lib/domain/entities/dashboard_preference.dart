/// Stores the dashboard GL account selections for an entity.
class DashboardPreference {
  final String entityId;
  final List<String> selectedGlIds;

  const DashboardPreference({
    required this.entityId,
    required this.selectedGlIds,
  });
}
