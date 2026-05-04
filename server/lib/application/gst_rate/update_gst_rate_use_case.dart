import '../../domain/entities/gst_rate.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Updates an existing GST rate.
class UpdateGstRateUseCase {
  final IGstRateRepository _repository;

  const UpdateGstRateUseCase(this._repository);

  /// Validates [rate], then updates the record.
  /// Throws [GstRateNotFoundException] or [GstRateDuplicateEffectiveDateException] as needed.
  Future<GstRate> execute({
    required String id,
    required double rate,
    required DateTime effectiveFrom,
  }) async {
    if (rate < 0 || rate > 1) {
      throw const GstRateValidationException(
        'Rate must be between 0 and 1 (e.g. 0.10 for 10%)',
      );
    }

    return _repository.update(id: id, rate: rate, effectiveFrom: effectiveFrom);
  }
}
