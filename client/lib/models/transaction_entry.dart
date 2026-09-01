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

/// A transaction record returned from the API.
class TransactionEntry {
  final String id;
  final String contactId;
  final String generalLedgerId;
  final String receiptNumber;
  final String? paymentReference;
  final String description;
  final String transactionType; // 'debit' | 'credit'
  final int amount;
  final int gstAmount;
  final int totalAmount; // in cents
  final String transactionDate; // 'YYYY-MM-DD'
  final bool bankMatched;
  final bool isCash;
  final String? abaBatchName;
  final String? bankAccountId;

  const TransactionEntry({
    required this.id,
    required this.contactId,
    required this.generalLedgerId,
    required this.receiptNumber,
    this.paymentReference,
    required this.description,
    required this.transactionType,
    required this.amount,
    required this.gstAmount,
    required this.totalAmount,
    required this.transactionDate,
    this.bankMatched = false,
    this.isCash = false,
    this.abaBatchName,
    this.bankAccountId,
  });

  factory TransactionEntry.fromJson(Map<String, dynamic> json) => TransactionEntry(
        id: json['id'] as String,
        contactId: json['contactId'] as String,
        generalLedgerId: json['generalLedgerId'] as String,
        receiptNumber: json['receiptNumber'] as String,
        paymentReference: json['paymentReference'] as String?,
        description: (json['description'] as String?) ?? '',
        transactionType: json['transactionType'] as String,
        amount: json['amount'] as int,
        gstAmount: json['gstAmount'] as int,
        totalAmount: json['totalAmount'] as int,
        transactionDate: json['transactionDate'] as String,
        bankMatched: (json['bankMatched'] as bool?) ?? false,
        isCash: (json['isCash'] as bool?) ?? false,
        abaBatchName: json['abaBatchName'] as String?,
        bankAccountId: json['bankAccountId'] as String?,
      );

  bool get isCredit => transactionType == 'credit';

  TransactionEntry copyWith({bool? bankMatched, String? bankAccountId}) =>
      TransactionEntry(
        id: id,
        contactId: contactId,
        generalLedgerId: generalLedgerId,
        receiptNumber: receiptNumber,
        paymentReference: paymentReference,
        description: description,
        transactionType: transactionType,
        amount: amount,
        gstAmount: gstAmount,
        totalAmount: totalAmount,
        transactionDate: transactionDate,
        bankMatched: bankMatched ?? this.bankMatched,
        isCash: isCash,
        abaBatchName: abaBatchName,
        bankAccountId: bankAccountId ?? this.bankAccountId,
      );
}
