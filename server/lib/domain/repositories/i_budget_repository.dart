import '../entities/budget_gl_mapping.dart';
import '../entities/budget_line.dart';

/// Contract for budget persistence.
abstract interface class IBudgetRepository {
  /// Returns all calendar years for which this entity has a budget, ascending.
  Future<List<int>> listYears({required String entityId});

  /// Returns all [BudgetLine]s for the given [year] and [entityId].
  /// Returns an empty list when no budget exists for that year.
  Future<List<BudgetLine>> getLines(int year, {required String entityId});

  /// Replaces all budget lines for [year] with [lines] within a single
  /// transaction. Creates the budget record if it does not already exist.
  Future<void> saveLines(
    int year,
    List<BudgetLine> lines, {
    required String entityId,
  });

  /// Deletes the budget for [year], including all its lines (cascade).
  /// Silently succeeds when no budget exists for that year.
  Future<void> delete(int year, {required String entityId});

  /// Returns all saved GL-code mappings for [entityId].
  Future<List<BudgetGlMapping>> getMappings({required String entityId});

  /// Replaces all GL-code mappings for [entityId] with [mappings].
  Future<void> saveMappings(
    List<BudgetGlMapping> mappings, {
    required String entityId,
  });
}
