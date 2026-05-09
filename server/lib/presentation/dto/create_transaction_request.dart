import '../../domain/entities/transaction.dart';

/// Deserialised request body for POST /transactions.
class CreateTransactionRequest {
  final String contactId;
  final String generalLedgerId;
  final int amount;
  final int gstAmount;
  final TransactionType transactionType;
  final String receiptNumber;
  final String description;
  final DateTime transactionDate;

  const CreateTransactionRequest({
    required this.contactId,
    required this.generalLedgerId,
    required this.amount,
    required this.gstAmount,
    required this.transactionType,
    required this.receiptNumber,
    required this.description,
    required this.transactionDate,
  });

  factory CreateTransactionRequest.fromJson(Map<String, dynamic> json) {
    final contactId = json['contactId'];
    final generalLedgerId = json['generalLedgerId'];
    final amount = json['amount'];
    final gstAmount = json['gstAmount'];
    final transactionTypeRaw = json['transactionType'];
    final receiptNumber = json['receiptNumber'];
    final description = json['description'] ?? '';
    final transactionDateRaw = json['transactionDate'];

    if (contactId is! String) throw const FormatException('contactId must be a string');
    if (generalLedgerId is! String) throw const FormatException('generalLedgerId must be a string');
    if (amount is! int) throw const FormatException('amount must be an integer (cents)');
    if (gstAmount is! int) throw const FormatException('gstAmount must be an integer (cents)');
    if (transactionTypeRaw is! String) throw const FormatException('transactionType must be a string');
    if (receiptNumber is! String) throw const FormatException('receiptNumber must be a string');
    if (description is! String) throw const FormatException('description must be a string');
    if (transactionDateRaw is! String) throw const FormatException('transactionDate must be an ISO 8601 date string');

    final TransactionType transactionType;
    try {
      transactionType = TransactionType.values.byName(transactionTypeRaw);
    } on ArgumentError {
      throw FormatException(
        'transactionType must be one of: ${TransactionType.values.map((e) => e.name).join(', ')}',
      );
    }

    final DateTime transactionDate;
    try {
      transactionDate = DateTime.parse(transactionDateRaw).toUtc();
    } on FormatException {
      throw const FormatException('transactionDate must be a valid ISO 8601 date');
    }

    return CreateTransactionRequest(
      contactId: contactId,
      generalLedgerId: generalLedgerId,
      amount: amount,
      gstAmount: gstAmount,
      transactionType: transactionType,
      receiptNumber: receiptNumber,
      description: description as String,
      transactionDate: transactionDate,
    );
  }
}
