import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/utils/cba_receipt_parser.dart';
import 'package:shedbooks_client/utils/receipt_format.dart';

void main() {
  // Format used for all debit tests — mirrors real P-number format.
  const pFormat = ReceiptFormat('P-?YY###');
  final date2026 = DateTime(2026, 5, 11);

  group('parseCbaReceiptNumbers', () {
    // ── Empty / no format ───────────────────────────────────────────────────────

    test('returns empty list when format is empty', () {
      expect(
        parseCbaReceiptNumbers('P-26075', const ReceiptFormat(''), at: date2026),
        isEmpty,
      );
    });

    test('returns empty list when description has no matching receipt', () {
      expect(
        parseCbaReceiptNumbers('BPAY transfer', pFormat, at: date2026),
        isEmpty,
      );
    });

    test('returns empty list for empty description', () {
      expect(parseCbaReceiptNumbers('', pFormat, at: date2026), isEmpty);
    });

    test('returns empty list when year does not match', () {
      expect(
        parseCbaReceiptNumbers('P-25075', pFormat, at: date2026),
        isEmpty,
      );
    });

    // ── Single number ───────────────────────────────────────────────────────────

    test('parses a single number without dash — normalises to canonical P-', () {
      expect(
        parseCbaReceiptNumbers('P26075', pFormat, at: date2026),
        equals(['P-26075']),
      );
    });

    test('parses a single number with dash', () {
      expect(
        parseCbaReceiptNumbers('P-26075', pFormat, at: date2026),
        equals(['P-26075']),
      );
    });

    test('ignores surrounding text', () {
      expect(
        parseCbaReceiptNumbers(
            'Payment ref P-26075 via internet', pFormat,
            at: date2026),
        equals(['P-26075']),
      );
    });

    // ── Ranges ──────────────────────────────────────────────────────────────────

    test('P-26001-10 expands to 10 entries', () {
      final result =
          parseCbaReceiptNumbers('P-26001-10', pFormat, at: date2026);
      expect(result.length, equals(10));
      expect(result.first, equals('P-26001'));
      expect(result.last, equals('P-26010'));
      expect(result, equals([
        'P-26001', 'P-26002', 'P-26003', 'P-26004', 'P-26005',
        'P-26006', 'P-26007', 'P-26008', 'P-26009', 'P-26010',
      ]));
    });

    test('P26062-67 expands to 6 entries, normalised with dash', () {
      final result =
          parseCbaReceiptNumbers('P26062-67', pFormat, at: date2026);
      expect(result.length, equals(6));
      expect(result, equals([
        'P-26062', 'P-26063', 'P-26064', 'P-26065', 'P-26066', 'P-26067',
      ]));
    });

    test('P-26075-81 expands to 7 entries', () {
      final result =
          parseCbaReceiptNumbers('P-26075-81', pFormat, at: date2026);
      expect(result.length, equals(7));
      expect(result.first, equals('P-26075'));
      expect(result.last, equals('P-26081'));
    });

    // ── Comma-separated lists ────────────────────────────────────────────────────

    test('P-26001,02 produces 2 entries', () {
      final result =
          parseCbaReceiptNumbers('P-26001,02', pFormat, at: date2026);
      expect(result.length, equals(2));
      expect(result, equals(['P-26001', 'P-26002']));
    });

    test('P26062-67,69 produces 7 entries', () {
      final result =
          parseCbaReceiptNumbers('P26062-67,69', pFormat, at: date2026);
      expect(result.length, equals(7));
      expect(result, equals([
        'P-26062', 'P-26063', 'P-26064', 'P-26065', 'P-26066', 'P-26067',
        'P-26069',
      ]));
    });

    test('P-26070,1,4 produces 3 entries', () {
      final result =
          parseCbaReceiptNumbers('P-26070,1,4', pFormat, at: date2026);
      expect(result.length, equals(3));
      expect(result, equals(['P-26070', 'P-26071', 'P-26074']));
    });

    // ── Mixed range and comma ────────────────────────────────────────────────────

    test('P-26001-10,12,14 produces 12 entries', () {
      final result =
          parseCbaReceiptNumbers('P-26001-10,12,14', pFormat, at: date2026);
      expect(result.length, equals(12));
      expect(result, equals([
        'P-26001', 'P-26002', 'P-26003', 'P-26004', 'P-26005',
        'P-26006', 'P-26007', 'P-26008', 'P-26009', 'P-26010',
        'P-26012', 'P-26014',
      ]));
    });

    test('range followed by individual comma entries', () {
      final result =
          parseCbaReceiptNumbers('P-26001-05,07,09', pFormat, at: date2026);
      expect(result.length, equals(7));
      expect(result, equals([
        'P-26001', 'P-26002', 'P-26003', 'P-26004', 'P-26005',
        'P-26007', 'P-26009',
      ]));
    });

    // ── Abbreviated suffix expansion ─────────────────────────────────────────────

    test('single-digit suffix expands using 4-char prefix', () {
      expect(
        parseCbaReceiptNumbers('P-26070,1', pFormat, at: date2026),
        equals(['P-26070', 'P-26071']),
      );
    });

    test('two-digit range suffix expands using 3-char prefix', () {
      expect(
        parseCbaReceiptNumbers('P-26001-10', pFormat, at: date2026).length,
        equals(10),
      );
    });

    test('three-digit suffix expands using 2-char prefix', () {
      final result =
          parseCbaReceiptNumbers('P-26001-075', pFormat, at: date2026);
      expect(result.first, equals('P-26001'));
      expect(result.last, equals('P-26075'));
      expect(result.length, equals(75));
    });

    // ── Edge cases ───────────────────────────────────────────────────────────────

    test('out-of-order suffix is silently skipped', () {
      expect(
        parseCbaReceiptNumbers('P-26062,01', pFormat, at: date2026),
        equals(['P-26062']),
      );
    });

    test('equal suffix is silently skipped', () {
      expect(
        parseCbaReceiptNumbers('P-26062,62', pFormat, at: date2026),
        equals(['P-26062']),
      );
    });

    test('zero-padded result', () {
      expect(
        parseCbaReceiptNumbers('P-26001', pFormat, at: date2026),
        equals(['P-26001']),
      );
    });

    // ── Credit descriptions with range notation ───────────────────────────────────

    test('parses range from a Direct Credit description', () {
      // "Direct Credit 301500 WoodgateMenShed Com P-26075-81" should expand to
      // P-26075 through P-26081 (7 receipts).
      final result = parseCbaReceiptNumbers(
        'Direct Credit 301500 WoodgateMenShed Com P-26075-81',
        pFormat,
        at: date2026,
      );
      expect(result, equals([
        'P-26075', 'P-26076', 'P-26077', 'P-26078',
        'P-26079', 'P-26080', 'P-26081',
      ]));
    });

    test('parses single receipt from a Direct Credit description', () {
      final result = parseCbaReceiptNumbers(
        'Direct Credit 301500 WoodgateMenShed Com P-26075',
        pFormat,
        at: date2026,
      );
      expect(result, equals(['P-26075']));
    });

    test('parses comma-separated receipts from a credit description', () {
      final result = parseCbaReceiptNumbers(
        'Direct Credit WoodgateMenShed P-26075,76,78',
        pFormat,
        at: date2026,
      );
      expect(result, equals(['P-26075', 'P-26076', 'P-26078']));
    });

    // ── Different format ─────────────────────────────────────────────────────────

    test('works with a plain 7-digit format', () {
      const fmt = ReceiptFormat('#######');
      expect(
        parseCbaReceiptNumbers('ref 0012345', fmt, at: date2026),
        equals(['0012345']),
      );
    });

    test('works with format that has no prefix', () {
      const fmt = ReceiptFormat('YY####');
      expect(
        parseCbaReceiptNumbers('ref 260001-03', fmt, at: date2026),
        equals(['260001', '260002', '260003']),
      );
    });
  });

  group('extractCreditReceipt', () {
    test('returns null when format is empty', () {
      expect(
        extractCreditReceipt('anything', const ReceiptFormat(''), at: date2026),
        isNull,
      );
    });

    test('returns null when no match found', () {
      expect(
        extractCreditReceipt('BPAY credit', pFormat, at: date2026),
        isNull,
      );
    });

    test('returns null when year does not match', () {
      expect(
        extractCreditReceipt('Receipt P-25001', pFormat, at: date2026),
        isNull,
      );
    });

    test('extracts a single receipt number with dash', () {
      expect(
        extractCreditReceipt('Credit P-26001', pFormat, at: date2026),
        equals('P-26001'),
      );
    });

    test('extracts a single receipt number without dash', () {
      expect(
        extractCreditReceipt('Credit P26001', pFormat, at: date2026),
        equals('P26001'),
      );
    });

    test('extracts from surrounding text', () {
      expect(
        extractCreditReceipt(
            'Bank deposit ref P-26042 member payment', pFormat,
            at: date2026),
        equals('P-26042'),
      );
    });

    test('returns first match only — does not expand CBA range notation', () {
      // extractCreditReceipt intentionally stops at the first match.
      // Use parseCbaReceiptNumbers when the description may contain a range.
      expect(
        extractCreditReceipt('P-26001-10', pFormat, at: date2026),
        equals('P-26001'),
      );
    });

    test('works with a plain digit format', () {
      const fmt = ReceiptFormat('#######');
      expect(
        extractCreditReceipt('Deposit 0012345 cleared', fmt, at: date2026),
        equals('0012345'),
      );
    });
  });
}
