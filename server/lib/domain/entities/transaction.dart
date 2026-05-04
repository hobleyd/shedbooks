/// Classifies whether money is flowing out of or into the account.
enum TransactionType { debit, credit }

/// A financial transaction posted against a contact and a general ledger account.
class Transaction {
  /// Unique identifier (UUID v4).
  final String id;

  /// FK — the contact this transaction is associated with.
  final String contactId;

  /// FK — the general ledger account this transaction is coded to.
  final String generalLedgerId;

  /// Transaction value in cents (always positive; direction is given by [transactionType]).
  final int amount;

  /// GST component of the transaction in cents (0 when GST does not apply).
  final int gstAmount;

  /// Whether this transaction is a debit or a credit.
  final TransactionType transactionType;

  /// External receipt or reference number for document tracking.
  final String receiptNumber;

  /// The date the transaction occurred.
  final DateTime transactionDate;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const Transaction({
    required this.id,
    required this.contactId,
    required this.generalLedgerId,
    required this.amount,
    required this.gstAmount,
    required this.transactionType,
    required this.receiptNumber,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
}
