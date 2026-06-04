import '../../domain/entities/budget_gl_mapping.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// Replaces all GL-code mappings for an entity.
class SaveBudgetGlMappingsUseCase {
  final IBudgetRepository _repository;

  const SaveBudgetGlMappingsUseCase(this._repository);

  Future<void> execute(
    List<BudgetGlMapping> mappings, {
    required String entityId,
  }) =>
      _repository.saveMappings(mappings, entityId: entityId);
}
