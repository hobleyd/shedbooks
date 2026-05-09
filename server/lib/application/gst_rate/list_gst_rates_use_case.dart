import '../../domain/entities/gst_rate.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Returns all active GST rates for an entity ordered by effectiveFrom descending.
class ListGstRatesUseCase {
  final IGstRateRepository _repository;

  const ListGstRatesUseCase(this._repository);

  Future<List<GstRate>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
