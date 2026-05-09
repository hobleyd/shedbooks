import '../../domain/entities/gst_rate.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Returns the GST rate effective at a given point in time.
class GetEffectiveGstRateUseCase {
  final IGstRateRepository _repository;

  const GetEffectiveGstRateUseCase(this._repository);

  Future<GstRate> execute({required String entityId, DateTime? date}) async {
    final target = date ?? DateTime.now().toUtc();
    final rate = await _repository.findEffectiveAt(target, entityId: entityId);
    if (rate == null) throw GstRateNotEffectiveException(target);
    return rate;
  }
}
