import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Soft-deletes a GST rate.
class DeleteGstRateUseCase {
  final IGstRateRepository _repository;

  const DeleteGstRateUseCase(this._repository);

  Future<void> execute(String id, {required String entityId}) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw GstRateNotFoundException(id);
    await _repository.delete(id, entityId: entityId);
  }
}
