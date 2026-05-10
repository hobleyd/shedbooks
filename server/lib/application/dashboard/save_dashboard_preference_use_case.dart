import '../../domain/entities/dashboard_preference.dart';
import '../../domain/repositories/i_dashboard_preference_repository.dart';

/// Persists the dashboard GL account pair selections for an entity.
class SaveDashboardPreferenceUseCase {
  final IDashboardPreferenceRepository _repository;

  const SaveDashboardPreferenceUseCase(this._repository);

  Future<void> execute(
      String entityId, List<GlAccountPair> selectedAccountPairs) async {
    await _repository.save(
      DashboardPreference(
          entityId: entityId, selectedAccountPairs: selectedAccountPairs),
    );
  }
}
