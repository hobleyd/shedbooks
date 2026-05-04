/// A GST rate that applies from a specific date.
///
/// The applicable rate at any point in time is the record with the
/// highest [effectiveFrom] that is on or before that date.
class GstRate {
  /// Unique identifier (UUID v4).
  final String id;

  /// The rate as a decimal fraction — e.g. 0.10 represents 10%.
  final double rate;

  /// The date from which this rate applies.
  final DateTime effectiveFrom;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const GstRate({
    required this.id,
    required this.rate,
    required this.effectiveFrom,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Returns the rate as a percentage — e.g. 10.0 for a rate of 0.10.
  double get rateAsPercentage => rate * 100;
}
