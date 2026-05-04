import 'dart:convert';
import '../../domain/entities/gst_rate.dart';

/// JSON response shape for a GST rate.
class GstRateResponse {
  final String id;
  final double rate;
  final String effectiveFrom;
  final String createdAt;
  final String updatedAt;

  const GstRateResponse({
    required this.id,
    required this.rate,
    required this.effectiveFrom,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GstRateResponse.fromEntity(GstRate entity) {
    return GstRateResponse(
      id: entity.id,
      rate: entity.rate,
      effectiveFrom: entity.effectiveFrom.toIso8601String().substring(0, 10),
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rate': rate,
        'effectiveFrom': effectiveFrom,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
