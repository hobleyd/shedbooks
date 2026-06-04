import '../../domain/entities/general_ledger.dart';

/// Deserialised request body for POST /general-ledger.
class CreateGeneralLedgerRequest {
  final String label;
  final String description;
  final bool gstApplicable;
  final GlDirection direction;
  final String? parentId;

  const CreateGeneralLedgerRequest({
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    this.parentId,
  });

  factory CreateGeneralLedgerRequest.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final description = json['description'];
    final gstApplicable = json['gstApplicable'];
    final direction = json['direction'];
    final parentId = json['parentId'];

    if (label is! String) throw FormatException('label must be a string');
    if (description is! String) throw FormatException('description must be a string');
    if (gstApplicable is! bool) throw FormatException('gstApplicable must be a boolean');
    if (direction is! String || (direction != 'moneyIn' && direction != 'moneyOut')) {
      throw FormatException('direction must be "moneyIn" or "moneyOut"');
    }
    if (parentId != null && parentId is! String) {
      throw FormatException('parentId must be a string or null');
    }

    return CreateGeneralLedgerRequest(
      label: label,
      description: description,
      gstApplicable: gstApplicable,
      direction: direction == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
      parentId: parentId as String?,
    );
  }
}
