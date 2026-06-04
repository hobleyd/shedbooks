/// A single monthly budget amount for one GL account within a budget year.
class BudgetLine {
  /// UUID of the general ledger account.
  final String generalLedgerId;

  /// Calendar month: 1 (January) through 12 (December).
  final int month;

  /// Budgeted amount in cents (always non-negative).
  final int amountCents;

  const BudgetLine({
    required this.generalLedgerId,
    required this.month,
    required this.amountCents,
  });
}
