import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Updates an existing contact.
class UpdateContactUseCase {
  final IContactRepository _repository;

  const UpdateContactUseCase(this._repository);

  /// Validates input and enforces the person/GST rule before updating.
  /// Throws [ContactNotFoundException] when [id] does not exist.
  Future<Contact> execute({
    required String id,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
  }) async {
    if (name.trim().isEmpty) {
      throw const ContactValidationException('Name must not be empty');
    }
    if (contactType == ContactType.person && gstRegistered) {
      throw const ContactValidationException(
        'A person contact cannot be GST registered',
      );
    }

    return _repository.update(
      id: id,
      name: name.trim(),
      contactType: contactType,
      gstRegistered: gstRegistered,
    );
  }
}
