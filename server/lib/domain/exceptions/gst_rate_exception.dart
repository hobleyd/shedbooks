/// Base class for all GST rate domain exceptions.
sealed class GstRateException implements Exception {
  final String message;
  const GstRateException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested GST rate does not exist (or is deleted).
final class GstRateNotFoundException extends GstRateException {
  final String id;
  const GstRateNotFoundException(this.id)
      : super('GST rate not found: $id');
}

/// Thrown when no rate is effective at the requested date.
final class GstRateNotEffectiveException extends GstRateException {
  final DateTime date;
  GstRateNotEffectiveException(this.date)
      : super('No GST rate is effective at ${date.toIso8601String()}');
}

/// Thrown when a rate with the same effective-from date already exists.
final class GstRateDuplicateEffectiveDateException extends GstRateException {
  final DateTime effectiveFrom;
  GstRateDuplicateEffectiveDateException(this.effectiveFrom)
      : super(
          'A GST rate already exists with effective date '
          '${effectiveFrom.toIso8601String()}',
        );
}

/// Thrown when input data fails domain validation.
final class GstRateValidationException extends GstRateException {
  const GstRateValidationException(super.message);
}
