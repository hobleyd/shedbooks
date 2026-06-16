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

import '../../domain/entities/transaction.dart';

/// Deserialised request body for PUT /transactions/:id.
class UpdateTransactionRequest {
  final String contactId;
  final String generalLedgerId;
  final int amount;
  final int gstAmount;
  final TransactionType transactionType;
  final String receiptNumber;
  final String description;
  final DateTime transactionDate;

  /// When non-null, explicitly sets is_cash. Null means preserve the existing value.
  final bool? isCash;

  const UpdateTransactionRequest({
    required this.contactId,
    required this.generalLedgerId,
    required this.amount,
    required this.gstAmount,
    required this.transactionType,
    required this.receiptNumber,
    required this.description,
    required this.transactionDate,
    this.isCash,
  });

  factory UpdateTransactionRequest.fromJson(Map<String, dynamic> json) {
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

    final isCashRaw = json['isCash'];
    if (isCashRaw != null && isCashRaw is! bool) {
      throw const FormatException('isCash must be a boolean');
    }

    return UpdateTransactionRequest(
      contactId: contactId,
      generalLedgerId: generalLedgerId,
      amount: amount,
      gstAmount: gstAmount,
      transactionType: transactionType,
      receiptNumber: receiptNumber,
      description: description,
      transactionDate: transactionDate,
      isCash: isCashRaw as bool?,
    );
  }
}
