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
import 'package:shedbooks_client/utils/receipt_format.dart';

void main() {
  // Fixed reference date so year tokens are deterministic.
  final date2026 = DateTime(2026, 5, 11);

  group('ReceiptFormat.isEmpty', () {
    test('empty string is empty', () {
      expect(ReceiptFormat('').isEmpty, isTrue);
    });

    test('whitespace-only is empty', () {
      expect(ReceiptFormat('   ').isEmpty, isTrue);
    });

    test('non-empty pattern is not empty', () {
      expect(ReceiptFormat('#').isEmpty, isFalse);
    });
  });

  group('ReceiptFormat.example', () {
    test('# produces a digit placeholder', () {
      expect(ReceiptFormat('#').example(at: date2026), equals('0'));
    });

    test('@ produces a letter placeholder', () {
      expect(ReceiptFormat('@').example(at: date2026), equals('A'));
    });

    test('* produces an alphanumeric placeholder', () {
      expect(ReceiptFormat('*').example(at: date2026), equals('0'));
    });

    test('YY produces 2-digit year', () {
      expect(ReceiptFormat('YY').example(at: date2026), equals('26'));
    });

    test('YYYY produces 4-digit year', () {
      expect(ReceiptFormat('YYYY').example(at: date2026), equals('2026'));
    });

    test('optional literal x? is included in example', () {
      expect(ReceiptFormat('-?').example(at: date2026), equals('-'));
    });

    test('required literal is included unchanged', () {
      expect(ReceiptFormat('P').example(at: date2026), equals('P'));
    });

    test('combined P-?YY### pattern', () {
      expect(ReceiptFormat('P-?YY###').example(at: date2026), equals('P-26000'));
    });

    test('YYYY-## pattern', () {
      expect(ReceiptFormat('YYYY-##').example(at: date2026), equals('2026-00'));
    });

    test('####### pattern produces seven zeros', () {
      expect(ReceiptFormat('#######').example(at: date2026), equals('0000000'));
    });

    test('empty pattern returns empty string', () {
      expect(ReceiptFormat('').example(at: date2026), equals(''));
    });

    test('year changes with reference date', () {
      expect(ReceiptFormat('YY').example(at: DateTime(2030, 1, 1)), equals('30'));
      expect(ReceiptFormat('YYYY').example(at: DateTime(2030, 1, 1)), equals('2030'));
    });
  });

  group('ReceiptFormat.toRegExp', () {
    test('# matches exactly one digit', () {
      final re = ReceiptFormat('#').toRegExp(at: date2026);
      expect(re.hasMatch('5'), isTrue);
      expect(re.hasMatch('a'), isFalse);
      expect(re.hasMatch('55'), isFalse);
    });

    test('@ matches exactly one letter', () {
      final re = ReceiptFormat('@').toRegExp(at: date2026);
      expect(re.hasMatch('A'), isTrue);
      expect(re.hasMatch('z'), isTrue);
      expect(re.hasMatch('1'), isFalse);
      expect(re.hasMatch('AA'), isFalse);
    });

    test('* matches any alphanumeric character', () {
      final re = ReceiptFormat('*').toRegExp(at: date2026);
      expect(re.hasMatch('A'), isTrue);
      expect(re.hasMatch('9'), isTrue);
      expect(re.hasMatch('-'), isFalse);
    });

    test('YY matches the 2-digit year exactly', () {
      final re = ReceiptFormat('YY').toRegExp(at: date2026);
      expect(re.hasMatch('26'), isTrue);
      expect(re.hasMatch('25'), isFalse);
      expect(re.hasMatch('2026'), isFalse);
    });

    test('YYYY matches the 4-digit year exactly', () {
      final re = ReceiptFormat('YYYY').toRegExp(at: date2026);
      expect(re.hasMatch('2026'), isTrue);
      expect(re.hasMatch('2025'), isFalse);
      expect(re.hasMatch('26'), isFalse);
    });

    test('x? makes the literal optional', () {
      final re = ReceiptFormat('-?').toRegExp(at: date2026);
      expect(re.hasMatch('-'), isTrue);
      expect(re.hasMatch(''), isTrue);
      expect(re.hasMatch('--'), isFalse);
    });

    test('required literal must be present', () {
      final re = ReceiptFormat('P').toRegExp(at: date2026);
      expect(re.hasMatch('P'), isTrue);
      expect(re.hasMatch('Q'), isFalse);
      expect(re.hasMatch(''), isFalse);
    });

    test('special regex chars in literals are escaped', () {
      final re = ReceiptFormat('(#)').toRegExp(at: date2026);
      expect(re.hasMatch('(5)'), isTrue);
      expect(re.hasMatch('5'), isFalse);
    });

    test('P-?YY### matches with and without dash', () {
      final re = ReceiptFormat('P-?YY###').toRegExp(at: date2026);
      expect(re.hasMatch('P-26062'), isTrue);
      expect(re.hasMatch('P26062'), isTrue);
      expect(re.hasMatch('P-26999'), isTrue);
    });

    test('P-?YY### rejects wrong year', () {
      final re = ReceiptFormat('P-?YY###').toRegExp(at: date2026);
      expect(re.hasMatch('P-25062'), isFalse);
    });

    test('P-?YY### rejects too few digits', () {
      final re = ReceiptFormat('P-?YY###').toRegExp(at: date2026);
      expect(re.hasMatch('P-2606'), isFalse);
    });

    test('P-?YY### rejects too many digits', () {
      final re = ReceiptFormat('P-?YY###').toRegExp(at: date2026);
      expect(re.hasMatch('P-260620'), isFalse);
    });
  });

  group('ReceiptFormat.canonicalPrefix', () {
    test('P-?YY### has prefix P-', () {
      expect(ReceiptFormat('P-?YY###').canonicalPrefix, equals('P-'));
    });

    test('####### has empty prefix', () {
      expect(ReceiptFormat('#######').canonicalPrefix, equals(''));
    });

    test('YYYY-## has empty prefix (year token is numeric)', () {
      expect(ReceiptFormat('YYYY-##').canonicalPrefix, equals(''));
    });

    test('YY### has empty prefix', () {
      expect(ReceiptFormat('YY###').canonicalPrefix, equals(''));
    });

    test('INV-#### has prefix INV-', () {
      expect(ReceiptFormat('INV-####').canonicalPrefix, equals('INV-'));
    });

    test('empty format has empty prefix', () {
      expect(ReceiptFormat('').canonicalPrefix, equals(''));
    });
  });

  group('ReceiptFormat.toUnanchoredRegExp', () {
    test('matches a receipt anywhere in a longer string', () {
      final re = ReceiptFormat('P-?YY###').toUnanchoredRegExp(at: date2026);
      expect(re.hasMatch('Payment ref P-26001 done'), isTrue);
      expect(re.hasMatch('P-26001'), isTrue);
    });

    test('does not reject leading/trailing text', () {
      final re = ReceiptFormat('#######').toUnanchoredRegExp(at: date2026);
      expect(re.hasMatch('ref 1234567 ok'), isTrue);
    });

    test('firstMatch returns only the matched portion', () {
      final re = ReceiptFormat('P-?YY###').toUnanchoredRegExp(at: date2026);
      final m = re.firstMatch('Payment P-26042 via bank');
      expect(m?.group(0), equals('P-26042'));
    });

    test('rejects non-matching year', () {
      final re = ReceiptFormat('P-?YY###').toUnanchoredRegExp(at: date2026);
      expect(re.hasMatch('P-25042'), isFalse);
    });
  });

  group('ReceiptFormat.nextReceipt', () {
    test('empty list returns first number (001 for ###)', () {
      expect(
        ReceiptFormat('###').nextReceipt([], at: date2026),
        equals('001'),
      );
    });

    test('single existing receipt increments by one', () {
      expect(
        ReceiptFormat('###').nextReceipt(['005'], at: date2026),
        equals('006'),
      );
    });

    test('finds max across multiple existing receipts', () {
      expect(
        ReceiptFormat('###').nextReceipt(['003', '007', '002'], at: date2026),
        equals('008'),
      );
    });

    test('P-?YY### increments with dash variant', () {
      expect(
        ReceiptFormat('P-?YY###').nextReceipt(
          ['P-26001', 'P-26003', 'P26002'],
          at: date2026,
        ),
        equals('P-26004'),
      );
    });

    test('ignores receipts from a different year', () {
      expect(
        ReceiptFormat('YY##').nextReceipt(['2599', '2601'], at: date2026),
        equals('2602'),
      );
    });

    test('receipts not matching format are ignored', () {
      expect(
        ReceiptFormat('P-?YY###').nextReceipt(
          ['INV-26001', 'RANDOM'],
          at: date2026,
        ),
        equals('P-26001'),
      );
    });

    test('format with no # tokens returns example', () {
      expect(
        ReceiptFormat('P-YY').nextReceipt(['P-26', 'P-25'], at: date2026),
        equals('P-26'),
      );
    });

    test('empty format returns empty string', () {
      expect(ReceiptFormat('').nextReceipt(['anything'], at: date2026), equals(''));
    });

    test('number overflows digit count gracefully', () {
      // 3 # digits, highest is 999, next is 1000 (4 digits written as-is)
      expect(
        ReceiptFormat('###').nextReceipt(['999'], at: date2026),
        equals('1000'),
      );
    });
  });

  group('ReceiptFormat.matches', () {
    test('empty format matches any string', () {
      final fmt = ReceiptFormat('');
      expect(fmt.matches('anything'), isTrue);
      expect(fmt.matches(''), isTrue);
    });

    test('non-empty format delegates to toRegExp', () {
      final fmt = ReceiptFormat('P-?YY###');
      expect(fmt.matches('P-26001', at: date2026), isTrue);
      expect(fmt.matches('P-25001', at: date2026), isFalse);
    });
  });
}
