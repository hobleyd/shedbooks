import '../../domain/exceptions/transaction_exception.dart';

/// Shared validation logic for transaction use cases.
abstract final class TransactionValidator {
  static void validate({
    required int amount,
    required int gstAmount,
    required String receiptNumber,
  }) {
    if (amount <= 0) {
      throw const TransactionValidationException(
        'Amount must be greater than zero',
      );
    }
    if (gstAmount < 0) {
      throw const TransactionValidationException(
        'GST amount must not be negative',
      );
    }
    if (gstAmount > amount) {
      throw const TransactionValidationException(
        'GST amount must not exceed the transaction amount',
      );
    }
    if (receiptNumber.trim().isEmpty) {
      throw const TransactionValidationException(
        'Receipt number must not be empty',
      );
    }
  }
}
