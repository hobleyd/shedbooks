import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Retrieves a single contact by ID.
class GetContactUseCase {
  final IContactRepository _repository;

  const GetContactUseCase(this._repository);

  /// Returns the contact or throws [ContactNotFoundException].
  Future<Contact> execute(String id) async {
    final contact = await _repository.findById(id);
    if (contact == null) throw ContactNotFoundException(id);
    return contact;
  }
}
