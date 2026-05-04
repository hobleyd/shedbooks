/// Base class for all general ledger domain exceptions.
sealed class GeneralLedgerException implements Exception {
  final String message;
  const GeneralLedgerException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested general ledger account does not exist (or is deleted).
final class GeneralLedgerNotFoundException extends GeneralLedgerException {
  final String id;
  const GeneralLedgerNotFoundException(this.id)
      : super('General ledger account not found: $id');
}

/// Thrown when input data fails domain validation.
final class GeneralLedgerValidationException extends GeneralLedgerException {
  const GeneralLedgerValidationException(super.message);
}
