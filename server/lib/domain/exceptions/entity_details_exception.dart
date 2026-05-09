/// Base class for all entity details domain exceptions.
sealed class EntityDetailsException implements Exception {
  final String message;
  const EntityDetailsException(this.message);

  @override
  String toString() => message;
}

/// Thrown when no entity details have been saved for the entity yet.
final class EntityDetailsNotFoundException extends EntityDetailsException {
  const EntityDetailsNotFoundException(String entityId)
      : super('Entity details not found for: $entityId');
}

/// Thrown when input data fails domain validation.
final class EntityDetailsValidationException extends EntityDetailsException {
  const EntityDetailsValidationException(super.message);
}
