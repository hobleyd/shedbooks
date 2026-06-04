/// Thrown when a budget year is not found for an entity.
class BudgetNotFoundException implements Exception {
  final int year;
  const BudgetNotFoundException(this.year);
  String get message => 'Budget for year $year not found';
}

/// Thrown when budget input fails validation.
class BudgetValidationException implements Exception {
  final String message;
  const BudgetValidationException(this.message);
}
