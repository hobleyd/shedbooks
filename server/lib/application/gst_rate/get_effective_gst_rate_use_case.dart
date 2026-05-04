import '../../domain/entities/gst_rate.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Returns the GST rate effective at a given point in time.
class GetEffectiveGstRateUseCase {
  final IGstRateRepository _repository;

  const GetEffectiveGstRateUseCase(this._repository);

  /// Returns the applicable rate at [date] (defaults to now).
  /// Throws [GstRateNotEffectiveException] when no rate covers that date.
  Future<GstRate> execute([DateTime? date]) async {
    final target = date ?? DateTime.now().toUtc();
    final rate = await _repository.findEffectiveAt(target);
    if (rate == null) throw GstRateNotEffectiveException(target);
    return rate;
  }
}
