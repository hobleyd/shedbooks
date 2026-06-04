/// Whether a general ledger account records inflows or outflows.
enum GlDirection { moneyIn, moneyOut }

/// A general ledger account entry returned from the API.
class GeneralLedgerEntry {
  final String id;
  final String label;
  final String description;
  final bool gstApplicable;
  final GlDirection direction;

  /// Parent account ID; null for top-level accounts.
  final String? parentId;

  const GeneralLedgerEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    this.parentId,
  });

  factory GeneralLedgerEntry.fromJson(Map<String, dynamic> json) {
    return GeneralLedgerEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      gstApplicable: json['gstApplicable'] as bool,
      direction: json['direction'] == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
      parentId: json['parentId'] as String?,
    );
  }
}

/// Builds the full display path for [id] by walking the parent chain.
///
/// Example: given accounts [Fundraising, Recycling (child of Fundraising)],
/// returns "Fundraising > Recycling" for the Recycling account id.
String buildGlPath(List<GeneralLedgerEntry> all, String id) {
  final byId = {for (final g in all) g.id: g};
  final parts = <String>[];
  GeneralLedgerEntry? current = byId[id];
  while (current != null) {
    parts.insert(0, current.description);
    current = current.parentId != null ? byId[current.parentId!] : null;
  }
  if (parts.isEmpty) return id;
  return parts.join(' > ');
}
