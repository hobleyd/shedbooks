import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Retrieves a single contact by ID.
class GetContactUseCase {
  final IContactRepository _repository;

  const GetContactUseCase(this._repository);

  Future<Contact> execute(String id, {required String entityId}) async {
    final contact = await _repository.findById(id, entityId: entityId);
    if (contact == null) throw ContactNotFoundException(id);
    return contact;
  }
}
