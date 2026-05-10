/// Base class for all contact domain exceptions.
sealed class ContactException implements Exception {
  final String message;
  const ContactException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested contact does not exist (or is deleted).
final class ContactNotFoundException extends ContactException {
  final String id;
  const ContactNotFoundException(this.id)
      : super('Contact not found: $id');
}

/// Thrown when input data fails domain validation.
final class ContactValidationException extends ContactException {
  const ContactValidationException(super.message);
}

/// Thrown when attempting to delete a contact that still has active transactions.
final class ContactInUseException extends ContactException {
  const ContactInUseException(String id)
      : super('Contact $id cannot be deleted because it has transactions');
}
