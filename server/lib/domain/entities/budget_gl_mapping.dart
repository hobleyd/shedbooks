/// A mapping from an external (legacy) GL code to a current GL account UUID.
///
/// Stored per entity so CSV imports can auto-match previously confirmed mappings.
class BudgetGlMapping {
  /// Auth0 org ID of the owning entity.
  final String entityId;

  /// Account code from the external/legacy system.
  final String externalCode;

  /// Human-readable name from the external system.
  final String externalName;

  /// UUID of the matching GL account in this system.
  final String generalLedgerId;

  const BudgetGlMapping({
    required this.entityId,
    required this.externalCode,
    required this.externalName,
    required this.generalLedgerId,
  });
}
