import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Creates a new contact.
class CreateContactUseCase {
  final IContactRepository _repository;

  const CreateContactUseCase(this._repository);

  /// Validates [name] is non-empty and enforces the rule that persons
  /// cannot be GST registered.
  Future<Contact> execute({
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

    return _repository.create(
      name: name.trim(),
      contactType: contactType,
      gstRegistered: gstRegistered,
    );
  }
}
