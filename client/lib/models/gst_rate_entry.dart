/// A GST rate entry returned from the API.
class GstRateEntry {
  final String id;
  final double rate; // decimal fraction, e.g. 0.1 = 10%
  final DateTime effectiveFrom;

  const GstRateEntry({
    required this.id,
    required this.rate,
    required this.effectiveFrom,
  });

  factory GstRateEntry.fromJson(Map<String, dynamic> json) {
    return GstRateEntry(
      id: json['id'] as String,
      rate: (json['rate'] as num).toDouble(),
      effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
    );
  }
}
