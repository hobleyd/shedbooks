import '../../domain/entities/budget_gl_mapping.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// Returns all saved GL-code mappings for an entity.
class GetBudgetGlMappingsUseCase {
  final IBudgetRepository _repository;

  const GetBudgetGlMappingsUseCase(this._repository);

  Future<List<BudgetGlMapping>> execute({required String entityId}) =>
      _repository.getMappings(entityId: entityId);
}
