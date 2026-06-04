import '../../domain/repositories/i_budget_repository.dart';

/// Deletes the budget for a calendar year, including all its lines.
class DeleteBudgetUseCase {
  final IBudgetRepository _repository;

  const DeleteBudgetUseCase(this._repository);

  Future<void> execute(int year, {required String entityId}) =>
      _repository.delete(year, entityId: entityId);
}
