import '../../domain/entities/gst_rate.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Creates a new GST rate entry.
class CreateGstRateUseCase {
  final IGstRateRepository _repository;

  const CreateGstRateUseCase(this._repository);

  /// Validates [rate] is between 0 and 1 inclusive, then persists.
  Future<GstRate> execute({
    required double rate,
    required DateTime effectiveFrom,
  }) async {
    _validateRate(rate);

    return _repository.create(rate: rate, effectiveFrom: effectiveFrom);
  }

  static void _validateRate(double rate) {
    if (rate < 0 || rate > 1) {
      throw const GstRateValidationException(
        'Rate must be between 0 and 1 (e.g. 0.10 for 10%)',
      );
    }
  }
}
