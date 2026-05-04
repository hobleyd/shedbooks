import 'dart:convert';
import '../../domain/entities/transaction.dart';

/// JSON response shape for a transaction.
class TransactionResponse {
  final String id;
  final String contactId;
  final String generalLedgerId;
  final int amount;
  final int gstAmount;
  final String transactionType;
  final String receiptNumber;
  final String transactionDate;
  final String createdAt;
  final String updatedAt;

  const TransactionResponse({
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
  });

  factory TransactionResponse.fromEntity(Transaction entity) {
    return TransactionResponse(
      id: entity.id,
      contactId: entity.contactId,
      generalLedgerId: entity.generalLedgerId,
      amount: entity.amount,
      gstAmount: entity.gstAmount,
      transactionType: entity.transactionType.name,
      receiptNumber: entity.receiptNumber,
      transactionDate: entity.transactionDate.toIso8601String().substring(0, 10),
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contactId': contactId,
        'generalLedgerId': generalLedgerId,
        'amount': amount,
        'gstAmount': gstAmount,
        'transactionType': transactionType,
        'receiptNumber': receiptNumber,
        'transactionDate': transactionDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
