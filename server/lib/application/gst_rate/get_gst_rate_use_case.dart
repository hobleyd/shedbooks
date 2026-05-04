import '../../domain/entities/gst_rate.dart';
import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Retrieves a single GST rate by ID.
class GetGstRateUseCase {
  final IGstRateRepository _repository;

  const GetGstRateUseCase(this._repository);

  /// Returns the rate or throws [GstRateNotFoundException].
  Future<GstRate> execute(String id) async {
    final rate = await _repository.findById(id);
    if (rate == null) throw GstRateNotFoundException(id);
    return rate;
  }
}
