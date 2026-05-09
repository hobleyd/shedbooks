import '../../domain/entities/dashboard_preference.dart';
import '../../domain/repositories/i_dashboard_preference_repository.dart';

/// Persists the dashboard GL account selections for an entity.
class SaveDashboardPreferenceUseCase {
  final IDashboardPreferenceRepository _repository;

  const SaveDashboardPreferenceUseCase(this._repository);

  Future<void> execute(String entityId, List<String> selectedGlIds) async {
    await _repository.save(
      DashboardPreference(entityId: entityId, selectedGlIds: selectedGlIds),
    );
  }
}
