/// A paired income / expense GL account selection for the dashboard breakdown.
class GlAccountPair {
  final String incomeGlId;
  final String expenseGlId;

  const GlAccountPair({
    required this.incomeGlId,
    required this.expenseGlId,
  });
}

/// Stores the dashboard GL account pair selections for an entity.
class DashboardPreference {
  final String entityId;
  final List<GlAccountPair> selectedAccountPairs;

  const DashboardPreference({
    required this.entityId,
    required this.selectedAccountPairs,
  });
}
