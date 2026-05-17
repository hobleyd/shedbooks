import '../../domain/repositories/i_locked_month_repository.dart';

/// Locks a month so that no transactions in that period may be modified.
class LockMonthUseCase {
  final ILockedMonthRepository _repository;

  const LockMonthUseCase(this._repository);

  /// Locks [monthYear] (YYYY-MM format) for [entityId]. Idempotent.
  Future<void> execute(String entityId, String monthYear) {
    _validateFormat(monthYear);
    return _repository.lock(entityId, monthYear);
  }

  static void _validateFormat(String monthYear) {
    final re = RegExp(r'^\d{4}-(?:0[1-9]|1[0-2])$');
    if (!re.hasMatch(monthYear)) {
      throw ArgumentError('monthYear must be in YYYY-MM format, got: $monthYear');
    }
  }
}
