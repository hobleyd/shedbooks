import 'dart:convert';
import '../../domain/entities/general_ledger.dart';

/// JSON response shape for a general ledger account.
class GeneralLedgerResponse {
  final String id;
  final String label;
  final String description;
  final bool gstApplicable;
  final String direction;
  final String createdAt;
  final String updatedAt;

  const GeneralLedgerResponse({
    required this.id,
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GeneralLedgerResponse.fromEntity(GeneralLedger entity) {
    return GeneralLedgerResponse(
      id: entity.id,
      label: entity.label,
      description: entity.description,
      gstApplicable: entity.gstApplicable,
      direction: entity.direction == GlDirection.moneyIn ? 'moneyIn' : 'moneyOut',
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'gstApplicable': gstApplicable,
        'direction': direction,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
