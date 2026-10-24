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

/// Builds CommBiz BPAY upload files (CommBiz "BPay Payments" File
/// Specification v7, 1 March 2022).
///
/// The file is CSV with CRLF line endings. Each payment is written as its own
/// Header (`01`) + Payment Details (`50`) pair — the spec's "individual debit
/// for each payment" layout — so each payment appears as its own debit on the
/// bank statement and reconciliation can match it by date and amount. (Unlike
/// an ABA file, a BPAY file has no field the bank echoes back onto the
/// statement, so there is no batch name to match a single combined debit by.)
library;

/// Most payments CommBiz accepts in one BPAY file.
const int maxBpayPaymentsPerFile = 200;

final RegExp _billerCodePattern = RegExp(r'^\d{3,10}$');
final RegExp _crnPattern = RegExp(r'^\d{2,20}$');

/// Whether [code] is a valid BPAY Biller Code (3-10 digits — the spec's field
/// is 10 N, and real biller codes are at least 3 digits).
bool isValidBpayBillerCode(String code) => _billerCodePattern.hasMatch(code);

/// Whether [crn] is a valid BPAY Customer Reference Number (2-20 digits — the
/// spec's field is 20 N, so letters and punctuation are not allowed).
bool isValidBpayCrn(String crn) => _crnPattern.hasMatch(crn);

/// The CRN to pay a bill with: the transaction's [paymentReference] when set
/// (for bills with a per-invoice CRN), otherwise the contact's saved
/// [contactReference]. Null when neither is set.
String? resolveBpayCrn({String? paymentReference, String? contactReference}) {
  final String? override = paymentReference?.trim();
  if (override != null && override.isNotEmpty) return override;
  final String? saved = contactReference?.trim();
  return saved != null && saved.isNotEmpty ? saved : null;
}

/// The funding account as the spec's Payment Account field wants it: the
/// BSB's digits followed by the account number's digits (e.g. BSB `062-000`,
/// account `1234 5678` → `06200012345678`).
String bpayFundingAccount({required String bsb, required String accountNumber}) {
  final RegExp nonDigit = RegExp(r'[^0-9]');
  return '${bsb.replaceAll(nonDigit, '')}${accountNumber.replaceAll(nonDigit, '')}';
}

/// One payment to a BPAY biller.
class BpayPayment {
  /// BPAY Biller Code of the payee — digits only.
  final String billerCode;

  /// Customer Reference Number of the account being paid — digits only.
  final String crn;

  /// Amount to pay, in cents. Must be positive.
  final int amountCents;

  const BpayPayment({
    required this.billerCode,
    required this.crn,
    required this.amountCents,
  });
}

/// Builds a CommBiz BPAY upload file for [payments], debited from
/// [fundingAccount] (see [bpayFundingAccount]).
///
/// [createdAt] fills the File Creation Date/Time fields and [fileNumber] the
/// 3-digit File Number. The Payment Date is left blank so CommBiz pays on the
/// day the file is submitted — a date baked in at generation time would be
/// stale (and rejected) if the file were uploaded on a later day.
///
/// Throws [ArgumentError] when [payments] is empty or over
/// [maxBpayPaymentsPerFile], or any field fails the spec's format rules.
String buildBpayFile({
  required List<BpayPayment> payments,
  required String fundingAccount,
  required DateTime createdAt,
  required int fileNumber,
}) {
  if (payments.isEmpty) {
    throw ArgumentError.value(payments, 'payments', 'must not be empty');
  }
  if (payments.length > maxBpayPaymentsPerFile) {
    throw ArgumentError.value(payments.length, 'payments',
        'at most $maxBpayPaymentsPerFile payments per file');
  }
  if (!RegExp(r'^\d{1,20}$').hasMatch(fundingAccount)) {
    throw ArgumentError.value(
        fundingAccount, 'fundingAccount', 'must be 1-20 digits');
  }

  String two(int n) => n.toString().padLeft(2, '0');
  final String date =
      '${createdAt.year}${two(createdAt.month)}${two(createdAt.day)}';
  final String time =
      '${two(createdAt.hour)}${two(createdAt.minute)}${two(createdAt.second)}';
  final String fileNo = (fileNumber % 1000).toString().padLeft(3, '0');

  final StringBuffer buffer = StringBuffer();
  for (final BpayPayment p in payments) {
    if (!isValidBpayBillerCode(p.billerCode)) {
      throw ArgumentError.value(p.billerCode, 'billerCode', 'must be 3-10 digits');
    }
    if (!isValidBpayCrn(p.crn)) {
      throw ArgumentError.value(p.crn, 'crn', 'must be 2-20 digits');
    }
    if (p.amountCents <= 0) {
      throw ArgumentError.value(p.amountCents, 'amountCents', 'must be positive');
    }

    // Header: Record Type, File Creation Date, File Creation Time,
    // File Number, Payment Account, Payment Date (blank = submission day),
    // Number of Payment Records, Total Amount of Payments (cents).
    buffer
      ..write(<String>[
        '01', date, time, fileNo, fundingAccount, '', '1', '${p.amountCents}',
      ].join(','))
      ..write('\r\n');

    // Payment Details: 25 fields — only Record Type (1), Biller Code (9),
    // Customer Reference Number (11) and Amount (14) are populated; every
    // other field is reserved and must be empty.
    final List<String> detail = List<String>.filled(25, '');
    detail[0] = '50';
    detail[8] = p.billerCode;
    detail[10] = p.crn;
    detail[13] = '${p.amountCents}';
    buffer
      ..write(detail.join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}
