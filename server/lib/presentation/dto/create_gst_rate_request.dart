/// Deserialised request body for POST /gst-rates.
class CreateGstRateRequest {
  final double rate;
  final DateTime effectiveFrom;

  const CreateGstRateRequest({required this.rate, required this.effectiveFrom});

  factory CreateGstRateRequest.fromJson(Map<String, dynamic> json) {
    final rate = json['rate'];
    final effectiveFromRaw = json['effectiveFrom'];

    if (rate is! num) throw const FormatException('rate must be a number');
    if (effectiveFromRaw is! String) {
      throw const FormatException('effectiveFrom must be an ISO 8601 date string');
    }

    final DateTime effectiveFrom;
    try {
      effectiveFrom = DateTime.parse(effectiveFromRaw).toUtc();
    } on FormatException {
      throw const FormatException('effectiveFrom must be a valid ISO 8601 date');
    }

    return CreateGstRateRequest(
      rate: rate.toDouble(),
      effectiveFrom: effectiveFrom,
    );
  }
}
