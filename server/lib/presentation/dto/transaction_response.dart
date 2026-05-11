import 'dart:convert';
import '../../domain/entities/transaction.dart';

/// JSON response shape for a transaction.
class TransactionResponse {
  final String id;
  final String contactId;
  final String generalLedgerId;
  final int amount;
  final int gstAmount;
  final int totalAmount;
  final String transactionType;
  final String receiptNumber;
  final String description;
  final String transactionDate;
  final String createdAt;
  final String updatedAt;
  final bool bankMatched;

  const TransactionResponse({
    required this.id,
    required this.contactId,
    required this.generalLedgerId,
    required this.amount,
    required this.gstAmount,
    required this.totalAmount,
    required this.transactionType,
    required this.receiptNumber,
    required this.description,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    required this.bankMatched,
  });

  factory TransactionResponse.fromEntity(Transaction entity) {
    return TransactionResponse(
      id: entity.id,
      contactId: entity.contactId,
      generalLedgerId: entity.generalLedgerId,
      amount: entity.amount,
      gstAmount: entity.gstAmount,
      totalAmount: entity.totalAmount,
      transactionType: entity.transactionType.name,
      receiptNumber: entity.receiptNumber,
      description: entity.description,
      transactionDate: entity.transactionDate.toIso8601String().substring(0, 10),
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
      bankMatched: entity.bankMatched,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contactId': contactId,
        'generalLedgerId': generalLedgerId,
        'amount': amount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
        'transactionType': transactionType,
        'receiptNumber': receiptNumber,
        'description': description,
        'transactionDate': transactionDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'bankMatched': bankMatched,
      };

  String toJsonString() => jsonEncode(toJson());
}
