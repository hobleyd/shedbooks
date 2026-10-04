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
import '../../domain/entities/transaction_line.dart';

/// Deserialised request body for POST /transactions and PUT /transactions/:id
/// when the body carries a `lines` array — one payment coded to several
/// general ledger accounts.
class SplitTransactionRequest {
  final String contactId;
  final TransactionType transactionType;
  final String receiptNumber;
  final String? paymentReference;
  final DateTime transactionDate;

  /// Null means "not supplied": false on create, preserve existing on update.
  final bool? isCash;
  final String? bankAccountId;
  final List<TransactionLine> lines;

  const SplitTransactionRequest({
    required this.contactId,
    required this.transactionType,
    required this.receiptNumber,
    this.paymentReference,
    required this.transactionDate,
    this.isCash,
    this.bankAccountId,
    required this.lines,
  });

  /// Whether [json] is a split request, i.e. carries a `lines` value.
  static bool isSplit(Map<String, dynamic> json) => json['lines'] != null;

  factory SplitTransactionRequest.fromJson(Map<String, dynamic> json) {
    final contactId = json['contactId'];
    final transactionTypeRaw = json['transactionType'];
    final receiptNumber = json['receiptNumber'];
    final paymentReferenceRaw = json['paymentReference'];
    final transactionDateRaw = json['transactionDate'];
    final isCashRaw = json['isCash'];
    final bankAccountIdRaw = json['bankAccountId'];
    final linesRaw = json['lines'];

    if (contactId is! String) throw const FormatException('contactId must be a string');
    if (transactionTypeRaw is! String) throw const FormatException('transactionType must be a string');
    if (receiptNumber is! String) throw const FormatException('receiptNumber must be a string');
    if (paymentReferenceRaw != null && paymentReferenceRaw is! String) {
      throw const FormatException('paymentReference must be a string');
    }
    if (transactionDateRaw is! String) throw const FormatException('transactionDate must be an ISO 8601 date string');
    if (isCashRaw != null && isCashRaw is! bool) {
      throw const FormatException('isCash must be a boolean');
    }
    if (bankAccountIdRaw != null && bankAccountIdRaw is! String) {
      throw const FormatException('bankAccountId must be a string');
    }
    if (linesRaw is! List) throw const FormatException('lines must be an array');

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

    final List<TransactionLine> lines = [];
    for (final Object? lineRaw in linesRaw) {
      if (lineRaw is! Map<String, dynamic>) {
        throw const FormatException('each line must be an object');
      }
      final generalLedgerId = lineRaw['generalLedgerId'];
      final amount = lineRaw['amount'];
      final gstAmount = lineRaw['gstAmount'];
      final description = lineRaw['description'] ?? '';
      if (generalLedgerId is! String) throw const FormatException('line generalLedgerId must be a string');
      if (amount is! int) throw const FormatException('line amount must be an integer (cents)');
      if (gstAmount is! int) throw const FormatException('line gstAmount must be an integer (cents)');
      if (description is! String) throw const FormatException('line description must be a string');
      lines.add(TransactionLine(
        generalLedgerId: generalLedgerId,
        amount: amount,
        gstAmount: gstAmount,
        description: description,
      ));
    }

    return SplitTransactionRequest(
      contactId: contactId,
      transactionType: transactionType,
      receiptNumber: receiptNumber,
      paymentReference: paymentReferenceRaw as String?,
      transactionDate: transactionDate,
      isCash: isCashRaw as bool?,
      bankAccountId: bankAccountIdRaw as String?,
      lines: lines,
    );
  }
}
