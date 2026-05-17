import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/transaction_entry.dart';
import 'package:shedbooks_client/widgets/bank_match_widgets.dart';

TransactionEntry _tx({
  required String id,
  required String receipt,
  required int total,
  String date = '2026-04-01',
}) =>
    TransactionEntry(
      id: id,
      contactId: 'c1',
      generalLedgerId: 'gl1',
      receiptNumber: receipt,
      description: '',
      transactionType: 'debit',
      amount: total,
      gstAmount: 0,
      totalAmount: total,
      transactionDate: date,
    );

void main() {
  group('findMatchingSubset', () {
    // ── Exact single-record match ────────────────────────────────────────────

    test('single record matching target — returns it', () {
      final records = [_tx(id: '1', receipt: 'P-26001', total: 5000)];
      expect(findMatchingSubset(records, 5000), equals(records));
    });

    test('single record not matching target — returns null', () {
      final records = [_tx(id: '1', receipt: 'P-26001', total: 5000)];
      expect(findMatchingSubset(records, 9999), isNull);
    });

    // ── All records needed ───────────────────────────────────────────────────

    test('two distinct receipts — returns both when they sum to target', () {
      final r1 = _tx(id: '1', receipt: 'P-26001', total: 3000);
      final r2 = _tx(id: '2', receipt: 'P-26002', total: 2000);
      final result = findMatchingSubset([r1, r2], 5000);
      expect(result, containsAll([r1, r2]));
    });

    // ── Duplicate full-amount entries (pick one per receipt) ─────────────────

    test('two records same receipt same amount — returns only one', () {
      final r1 = _tx(id: '1', receipt: 'P-26001', total: 5000);
      final r2 = _tx(id: '2', receipt: 'P-26001', total: 5000);
      final result = findMatchingSubset([r1, r2], 5000);
      expect(result?.length, equals(1));
      expect(result?.single.totalAmount, equals(5000));
    });

    // ── Mixed: duplicate-month entry + legitimate split line items ───────────
    // Mirrors the real P26062-67,69 case:
    //   P-26062 has a stale Feb entry (29907) and the correct Apr entry (30320)
    //   P-26069 has two line items that should both be counted (583 + 3630)

    test('selects correct P-26062 and includes both P-26069 line items', () {
      final p26062feb = _tx(
          id: '1', receipt: 'P-26062', total: 29907, date: '2026-02-28');
      final p26062apr = _tx(
          id: '2', receipt: 'P-26062', total: 30320, date: '2026-04-01');
      final p26063 = _tx(id: '3', receipt: 'P-26063', total: 37874);
      final p26064 = _tx(id: '4', receipt: 'P-26064', total: 38896);
      final p26065 = _tx(id: '5', receipt: 'P-26065', total: 10710);
      final p26066 = _tx(id: '6', receipt: 'P-26066', total: 13752);
      final p26067 = _tx(id: '7', receipt: 'P-26067', total: 6001);
      final p26069a = _tx(id: '8', receipt: 'P-26069', total: 3630);
      final p26069b = _tx(id: '9', receipt: 'P-26069', total: 583);

      // Bank total: 30320+37874+38896+10710+13752+6001+3630+583 = 141766
      const bankAmount = 141766;

      final result = findMatchingSubset(
        [p26062feb, p26062apr, p26063, p26064, p26065, p26066, p26067, p26069a, p26069b],
        bankAmount,
      );

      expect(result, isNotNull);
      expect(result!.fold(0, (s, t) => s + t.totalAmount), equals(bankAmount));
      expect(result, isNot(contains(p26062feb))); // stale entry excluded
      expect(result, contains(p26062apr));
      expect(result, contains(p26069a));
      expect(result, contains(p26069b));
    });

    // ── Genuine mismatch — no subset sums to target ──────────────────────────

    test('no subset matches target — returns null', () {
      final records = [
        _tx(id: '1', receipt: 'P-26001', total: 4000),
        _tx(id: '2', receipt: 'P-26002', total: 3000),
      ];
      expect(findMatchingSubset(records, 5000), isNull);
    });

    // ── Empty / edge cases ───────────────────────────────────────────────────

    test('empty list — returns null', () {
      expect(findMatchingSubset([], 5000), isNull);
    });

    test('more than 20 records — returns null without blocking', () {
      final records = List.generate(
          21, (i) => _tx(id: '$i', receipt: 'P-$i', total: 100));
      expect(findMatchingSubset(records, 100), isNull);
    });
  });
}
