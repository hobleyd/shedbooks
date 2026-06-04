import '../../domain/entities/budget_line.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// Returns all budget lines for the given calendar year.
class GetBudgetUseCase {
  final IBudgetRepository _repository;

  const GetBudgetUseCase(this._repository);

  Future<List<BudgetLine>> execute(int year, {required String entityId}) =>
      _repository.getLines(year, entityId: entityId);
}
