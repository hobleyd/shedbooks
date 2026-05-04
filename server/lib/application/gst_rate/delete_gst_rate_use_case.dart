import '../../domain/exceptions/gst_rate_exception.dart';
import '../../domain/repositories/i_gst_rate_repository.dart';

/// Soft-deletes a GST rate.
class DeleteGstRateUseCase {
  final IGstRateRepository _repository;

  const DeleteGstRateUseCase(this._repository);

  /// Throws [GstRateNotFoundException] when [id] does not exist.
  Future<void> execute(String id) async {
    final existing = await _repository.findById(id);
    if (existing == null) throw GstRateNotFoundException(id);
    await _repository.delete(id);
  }
}
