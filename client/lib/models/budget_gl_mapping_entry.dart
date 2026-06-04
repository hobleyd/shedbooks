/// A saved mapping from an external GL code to a current GL account.
class BudgetGlMappingEntry {
  final String externalCode;
  final String externalName;
  final String generalLedgerId;

  const BudgetGlMappingEntry({
    required this.externalCode,
    required this.externalName,
    required this.generalLedgerId,
  });

  factory BudgetGlMappingEntry.fromJson(Map<String, dynamic> json) {
    return BudgetGlMappingEntry(
      externalCode: json['externalCode'] as String,
      externalName: json['externalName'] as String? ?? '',
      generalLedgerId: json['generalLedgerId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'externalCode': externalCode,
        'externalName': externalName,
        'generalLedgerId': generalLedgerId,
      };
}
