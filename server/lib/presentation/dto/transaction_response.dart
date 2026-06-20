// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
  final bool isCash;
  final String? abaBatchName;

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
    required this.isCash,
    this.abaBatchName,
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
      isCash: entity.isCash,
      abaBatchName: entity.abaBatchName,
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
        'isCash': isCash,
        if (abaBatchName != null) 'abaBatchName': abaBatchName,
      };

  String toJsonString() => jsonEncode(toJson());
}
