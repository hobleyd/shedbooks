/// Whether a general ledger account records inflows or outflows.
enum GlDirection { moneyIn, moneyOut }

/// A general ledger account entry returned from the API.
class GeneralLedgerEntry {
  final String id;
  final String label;
  final String description;
  final bool gstApplicable;
  final GlDirection direction;

  const GeneralLedgerEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
  });

  factory GeneralLedgerEntry.fromJson(Map<String, dynamic> json) {
    return GeneralLedgerEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      gstApplicable: json['gstApplicable'] as bool,
      direction: json['direction'] == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
    );
  }
}
