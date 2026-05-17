import '../../domain/entities/locked_month.dart';
import '../../domain/repositories/i_locked_month_repository.dart';

/// Returns all locked months for an entity.
class ListLockedMonthsUseCase {
  final ILockedMonthRepository _repository;

  const ListLockedMonthsUseCase(this._repository);

  /// Returns locked months ordered by month_year descending.
  Future<List<LockedMonth>> execute(String entityId) =>
      _repository.findAll(entityId);
}
