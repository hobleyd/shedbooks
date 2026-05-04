/// Deserialised request body for PUT /general-ledger/:id.
class UpdateGeneralLedgerRequest {
  final String label;
  final String description;
  final bool gstApplicable;

  const UpdateGeneralLedgerRequest({
    required this.label,
    required this.description,
    required this.gstApplicable,
  });

  factory UpdateGeneralLedgerRequest.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final description = json['description'];
    final gstApplicable = json['gstApplicable'];

    if (label is! String) throw FormatException('label must be a string');
    if (description is! String) throw FormatException('description must be a string');
    if (gstApplicable is! bool) throw FormatException('gstApplicable must be a boolean');

    return UpdateGeneralLedgerRequest(
      label: label,
      description: description,
      gstApplicable: gstApplicable,
    );
  }
}
