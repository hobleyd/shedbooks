import '../../domain/entities/budget_line.dart';
import '../../domain/exceptions/budget_exception.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// Replaces all budget lines for a calendar year (upsert semantics).
class SaveBudgetUseCase {
  final IBudgetRepository _repository;

  const SaveBudgetUseCase(this._repository);

  Future<void> execute(
    int year,
    List<BudgetLine> lines, {
    required String entityId,
  }) async {
    if (year < 1900 || year > 2200) {
      throw const BudgetValidationException('Year must be between 1900 and 2200');
    }
    await _repository.saveLines(year, lines, entityId: entityId);
  }
}
