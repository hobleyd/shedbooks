import '../../domain/entities/dashboard_preference.dart';
import '../../domain/repositories/i_dashboard_preference_repository.dart';

/// Returns the dashboard GL account selections for an entity.
/// When no preference has been saved, returns an empty preference.
class GetDashboardPreferenceUseCase {
  final IDashboardPreferenceRepository _repository;

  const GetDashboardPreferenceUseCase(this._repository);

  Future<DashboardPreference> execute(String entityId) async {
    return await _repository.find(entityId) ??
        DashboardPreference(entityId: entityId, selectedGlIds: const []);
  }
}
