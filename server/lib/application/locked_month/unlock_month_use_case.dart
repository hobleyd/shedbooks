import '../../domain/repositories/i_locked_month_repository.dart';

/// Removes a month lock, allowing transactions in that period to be modified again.
class UnlockMonthUseCase {
  final ILockedMonthRepository _repository;

  const UnlockMonthUseCase(this._repository);

  /// Unlocks [monthYear] (YYYY-MM format) for [entityId]. No-op if not locked.
  Future<void> execute(String entityId, String monthYear) =>
      _repository.unlock(entityId, monthYear);
}
