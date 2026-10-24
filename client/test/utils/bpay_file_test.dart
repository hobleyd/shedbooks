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
import 'package:shedbooks_client/utils/bpay_file.dart';

void main() {
  // The spec's own sample values (CommBiz BPay Payments v7, §1.2.2).
  const BpayPayment samplePayment =
      BpayPayment(billerCode: '7334', crn: '8923037123', amountCents: 130350);
  const String sampleAccount = '06200012345678';
  final DateTime sampleCreated = DateTime(2021, 3, 6, 10, 30, 51);

  group('buildBpayFile', () {
    test('writes the spec sample payment detail record exactly', () {
      // Arrange / Act
      final String file = buildBpayFile(
        payments: [samplePayment],
        fundingAccount: sampleAccount,
        createdAt: sampleCreated,
        fileNumber: 1,
      );

      // Assert
      final List<String> records = file.split('\r\n');
      expect(records[1], equals('50,,,,,,,,7334,,8923037123,,,130350,,,,,,,,,,,'));
    });

    test('writes a header with a blank payment date for each payment', () {
      // Arrange / Act
      final String file = buildBpayFile(
        payments: [samplePayment],
        fundingAccount: sampleAccount,
        createdAt: sampleCreated,
        fileNumber: 1,
      );

      // Assert
      final List<String> records = file.split('\r\n');
      expect(records[0], equals('01,20210306,103051,001,06200012345678,,1,130350'));
    });

    test('writes one header and one detail record per payment', () {
      // Arrange
      const BpayPayment second =
          BpayPayment(billerCode: '6666', crn: '12340001756', amountCents: 52573);

      // Act
      final String file = buildBpayFile(
        payments: [samplePayment, second],
        fundingAccount: sampleAccount,
        createdAt: sampleCreated,
        fileNumber: 7,
      );

      // Assert
      final List<String> records = file.split('\r\n');
      expect(records, hasLength(5)); // 4 records + empty after final CRLF
      expect(records.last, isEmpty);
      expect(records[0], startsWith('01,'));
      expect(records[1], startsWith('50,'));
      expect(records[2], equals('01,20210306,103051,007,06200012345678,,1,52573'));
      expect(records[3], equals('50,,,,,,,,6666,,12340001756,,,52573,,,,,,,,,,,'));
    });

    test('headers have 8 fields and details have 25 fields', () {
      // Arrange / Act
      final String file = buildBpayFile(
        payments: [samplePayment, samplePayment],
        fundingAccount: sampleAccount,
        createdAt: sampleCreated,
        fileNumber: 1,
      );

      // Assert
      for (final String record in file.split('\r\n').where((r) => r.isNotEmpty)) {
        final int fieldCount = record.split(',').length;
        expect(fieldCount, equals(record.startsWith('01') ? 8 : 25), reason: record);
      }
    });

    test('ends every record with CRLF and uses no bare LF', () {
      // Arrange / Act
      final String file = buildBpayFile(
        payments: [samplePayment],
        fundingAccount: sampleAccount,
        createdAt: sampleCreated,
        fileNumber: 1,
      );

      // Assert
      expect(file, endsWith('\r\n'));
      expect(file.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('rejects an empty payment list', () {
      // Act / Assert
      expect(
        () => buildBpayFile(
            payments: const [],
            fundingAccount: sampleAccount,
            createdAt: sampleCreated,
            fileNumber: 1),
        throwsArgumentError,
      );
    });

    test('rejects more than the maximum payments per file', () {
      // Arrange
      final List<BpayPayment> tooMany =
          List<BpayPayment>.filled(maxBpayPaymentsPerFile + 1, samplePayment);

      // Act / Assert
      expect(
        () => buildBpayFile(
            payments: tooMany,
            fundingAccount: sampleAccount,
            createdAt: sampleCreated,
            fileNumber: 1),
        throwsArgumentError,
      );
    });

    test('rejects a CRN containing letters', () {
      // Arrange
      const BpayPayment bad =
          BpayPayment(billerCode: '7334', crn: 'INV-123', amountCents: 100);

      // Act / Assert
      expect(
        () => buildBpayFile(
            payments: [bad],
            fundingAccount: sampleAccount,
            createdAt: sampleCreated,
            fileNumber: 1),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive amount', () {
      // Arrange
      const BpayPayment bad =
          BpayPayment(billerCode: '7334', crn: '8923037123', amountCents: 0);

      // Act / Assert
      expect(
        () => buildBpayFile(
            payments: [bad],
            fundingAccount: sampleAccount,
            createdAt: sampleCreated,
            fileNumber: 1),
        throwsArgumentError,
      );
    });

    test('rejects a funding account longer than 20 digits', () {
      // Act / Assert
      expect(
        () => buildBpayFile(
            payments: [samplePayment],
            fundingAccount: '1' * 21,
            createdAt: sampleCreated,
            fileNumber: 1),
        throwsArgumentError,
      );
    });
  });

  group('resolveBpayCrn', () {
    test('prefers the payment reference when set', () {
      // Act
      final String? crn =
          resolveBpayCrn(paymentReference: ' 555 ', contactReference: '111');

      // Assert
      expect(crn, equals('555'));
    });

    test('falls back to the contact reference when the payment reference is blank', () {
      // Act
      final String? crn =
          resolveBpayCrn(paymentReference: '  ', contactReference: '111');

      // Assert
      expect(crn, equals('111'));
    });

    test('is null when neither is set', () {
      // Act
      final String? crn = resolveBpayCrn(paymentReference: null, contactReference: '');

      // Assert
      expect(crn, isNull);
    });
  });

  group('bpayFundingAccount', () {
    test('concatenates BSB and account digits, dropping punctuation', () {
      // Act
      final String account =
          bpayFundingAccount(bsb: '062-000', accountNumber: '1234 5678');

      // Assert
      expect(account, equals('06200012345678'));
    });
  });

  group('format validators', () {
    test('biller code must be 3-10 digits', () {
      // Assert
      expect(isValidBpayBillerCode('7334'), isTrue);
      expect(isValidBpayBillerCode('12'), isFalse);
      expect(isValidBpayBillerCode('12345678901'), isFalse);
      expect(isValidBpayBillerCode('73A4'), isFalse);
    });

    test('CRN must be 2-20 digits', () {
      // Assert
      expect(isValidBpayCrn('8923037123'), isTrue);
      expect(isValidBpayCrn('1'), isFalse);
      expect(isValidBpayCrn('1' * 21), isFalse);
      expect(isValidBpayCrn('892-303'), isFalse);
    });
  });
}
