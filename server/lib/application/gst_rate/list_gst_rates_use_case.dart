import '../../domain/entities/gst_rate.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Returns all active GST rates ordered by effectiveFrom descending.
class ListGstRatesUseCase {
  final IGstRateRepository _repository;

  const ListGstRatesUseCase(this._repository);

  Future<List<GstRate>> execute() => _repository.findAll();
}
