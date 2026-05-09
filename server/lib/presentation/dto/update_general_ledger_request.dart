import '../../domain/entities/general_ledger.dart';

/// Deserialised request body for PUT /general-ledger/:id.
class UpdateGeneralLedgerRequest {
  final String label;
  final String description;
  final bool gstApplicable;
  final GlDirection direction;

  const UpdateGeneralLedgerRequest({
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
  });

  factory UpdateGeneralLedgerRequest.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final description = json['description'];
    final gstApplicable = json['gstApplicable'];
    final direction = json['direction'];

    if (label is! String) throw FormatException('label must be a string');
    if (description is! String) throw FormatException('description must be a string');
    if (gstApplicable is! bool) throw FormatException('gstApplicable must be a boolean');
    if (direction is! String || (direction != 'moneyIn' && direction != 'moneyOut')) {
      throw FormatException('direction must be "moneyIn" or "moneyOut"');
    }

    return UpdateGeneralLedgerRequest(
      label: label,
      description: description,
      gstApplicable: gstApplicable,
      direction: direction == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
    );
  }
}
