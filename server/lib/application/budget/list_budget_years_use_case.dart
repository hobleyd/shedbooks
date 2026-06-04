import '../../domain/repositories/i_budget_repository.dart';

/// Returns all calendar years for which an entity has a saved budget.
class ListBudgetYearsUseCase {
  final IBudgetRepository _repository;

  const ListBudgetYearsUseCase(this._repository);

  Future<List<int>> execute({required String entityId}) =>
      _repository.listYears(entityId: entityId);
}
