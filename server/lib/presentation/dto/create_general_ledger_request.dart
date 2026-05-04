/// Deserialised request body for POST /general-ledger.
class CreateGeneralLedgerRequest {
  final String label;
  final String description;
  final bool gstApplicable;

  const CreateGeneralLedgerRequest({
    required this.label,
    required this.description,
    required this.gstApplicable,
  });

  factory CreateGeneralLedgerRequest.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final description = json['description'];
    final gstApplicable = json['gstApplicable'];

    if (label is! String) throw FormatException('label must be a string');
    if (description is! String) throw FormatException('description must be a string');
    if (gstApplicable is! bool) throw FormatException('gstApplicable must be a boolean');

    return CreateGeneralLedgerRequest(
      label: label,
      description: description,
      gstApplicable: gstApplicable,
    );
  }
}
