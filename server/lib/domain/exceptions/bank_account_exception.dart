/// Base class for all bank account domain exceptions.
sealed class BankAccountException implements Exception {
  final String message;
  const BankAccountException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested bank account does not exist or has been deleted.
final class BankAccountNotFoundException extends BankAccountException {
  final String id;
  const BankAccountNotFoundException(this.id)
      : super('Bank account not found: $id');
}

/// Thrown when input data fails domain validation.
final class BankAccountValidationException extends BankAccountException {
  const BankAccountValidationException(super.message);
}

/// Thrown when an operation is attempted on a system-managed account.
final class BankAccountSystemException extends BankAccountException {
  const BankAccountSystemException()
      : super('System accounts cannot be modified or deleted');
}
