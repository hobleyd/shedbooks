/// Base class for all transaction domain exceptions.
sealed class TransactionException implements Exception {
  final String message;
  const TransactionException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested transaction does not exist (or is deleted).
final class TransactionNotFoundException extends TransactionException {
  final String id;
  const TransactionNotFoundException(this.id)
      : super('Transaction not found: $id');
}

/// Thrown when input data fails domain or referential validation.
final class TransactionValidationException extends TransactionException {
  const TransactionValidationException(super.message);
}
