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

import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/transaction_entry.dart';
import 'package:shedbooks_client/utils/bank_row_matching.dart';

TransactionEntry _tx({
  String id = 't1',
  String receipt = 'P-26001',
  String? paymentReference,
  int total = 5000,
}) =>
    TransactionEntry(
      id: id,
      contactId: 'c1',
      generalLedgerId: 'gl1',
      receiptNumber: receipt,
      paymentReference: paymentReference,
      description: '',
      transactionType: 'debit',
      amount: total,
      gstAmount: 0,
      totalAmount: total,
      transactionDate: '2026-04-01',
    );

void main() {
  group('referenceMatches', () {
    test('matches when the receipt number was recognised in the statement text', () {
      final t = _tx(receipt: 'P-26062');
      final matched = referenceMatches(
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062 RENT',
        transaction: t,
      );
      expect(matched, isTrue);
    });

    test('does not match when neither the receipt nor a payment reference is present', () {
      final t = _tx(receipt: 'P-26062');
      final matched = referenceMatches(
        parsedReceipts: ['P-26099'],
        description: 'EFT P26099 RENT',
        transaction: t,
      );
      expect(matched, isFalse);
    });

    test('matches via Payment Reference when the statement text contains it literally', () {
      final t = _tx(receipt: 'P-26062', paymentReference: 'INV-9876-REF');
      final matched = referenceMatches(
        parsedReceipts: const [], // free text — doesn't conform to the receipt format
        description: 'EFT INV-9876-REF ACME PTY LTD',
        transaction: t,
      );
      expect(matched, isTrue);
    });

    test('Payment Reference match is case-insensitive', () {
      final t = _tx(receipt: 'P-26062', paymentReference: 'inv-9876-ref');
      final matched = referenceMatches(
        parsedReceipts: const [],
        description: 'EFT INV-9876-REF ACME PTY LTD',
        transaction: t,
      );
      expect(matched, isTrue);
    });

    test('does not match when the Payment Reference is set but absent from the text', () {
      final t = _tx(receipt: 'P-26062', paymentReference: 'INV-9876-REF');
      final matched = referenceMatches(
        parsedReceipts: const [],
        description: 'EFT SOMETHING ELSE ENTIRELY',
        transaction: t,
      );
      expect(matched, isFalse);
    });

    test('a blank Payment Reference is treated as unset', () {
      final t = _tx(receipt: 'P-26062', paymentReference: '   ');
      final matched = referenceMatches(
        parsedReceipts: const [],
        description: 'EFT    ACME PTY LTD', // literal spaces would otherwise "match"
        transaction: t,
      );
      expect(matched, isFalse);
    });

    test('receipt number match takes priority even when a payment reference is also set', () {
      final t = _tx(receipt: 'P-26062', paymentReference: 'NOT-IN-TEXT');
      final matched = referenceMatches(
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062 RENT',
        transaction: t,
      );
      expect(matched, isTrue);
    });
  });

  group('extractAbaBatchName', () {
    test('extracts a WMS batch name from the description', () {
      expect(extractAbaBatchName('DIRECT DEBIT WMS260830001 XYZ'),
          equals('WMS260830001'));
    });

    test('returns null when no batch name is present', () {
      expect(extractAbaBatchName('EFT P26062 RENT'), isNull);
    });

    test('requires exactly 9 digits after WMS', () {
      expect(extractAbaBatchName('WMS12345678'), isNull); // 8 digits
      expect(extractAbaBatchName('WMS1234567890'), equals('WMS123456789')); // matches first 9
    });
  });
}
