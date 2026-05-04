import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Soft-deletes a contact.
class DeleteContactUseCase {
  final IContactRepository _repository;

  const DeleteContactUseCase(this._repository);

  /// Throws [ContactNotFoundException] when [id] does not exist.
  Future<void> execute(String id) async {
    final existing = await _repository.findById(id);
    if (existing == null) throw ContactNotFoundException(id);
    await _repository.delete(id);
  }
}
