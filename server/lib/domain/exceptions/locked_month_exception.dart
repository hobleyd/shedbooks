/// Base class for locked-month domain exceptions.
sealed class LockedMonthException implements Exception {
  final String message;
  const LockedMonthException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a mutating transaction operation targets a locked month.
final class MonthIsLockedException extends LockedMonthException {
  final String monthYear;
  const MonthIsLockedException(this.monthYear)
      : super('Month $monthYear is locked and cannot be modified');
}
