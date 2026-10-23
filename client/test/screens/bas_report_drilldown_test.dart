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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shedbooks_client/screens/bas_report_screen.dart';
import 'package:shedbooks_client/services/api_client.dart';
import 'package:shedbooks_client/services/reference_data_cache.dart';

void main() {
  /// A date inside the quarter the BAS screen opens on (the previous one).
  String dateInPreviousQuarter() {
    final DateTime now = DateTime.now();
    final int currentQ = (now.month - 1) ~/ 3 + 1;
    final int q = currentQ == 1 ? 4 : currentQ - 1;
    final int y = currentQ == 1 ? now.year - 1 : now.year;
    final int month = (q - 1) * 3 + 2;
    return '$y-${month.toString().padLeft(2, '0')}-15';
  }

  Map<String, dynamic> txn(String id, String type, String gl, int gst,
          int total, String receipt, String date) =>
      {
        'id': id,
        'contactId': 'c1',
        'generalLedgerId': gl,
        'receiptNumber': receipt,
        'description': 'Desc $id',
        'transactionType': type,
        'amount': total - gst,
        'gstAmount': gst,
        'totalAmount': total,
        'transactionDate': date,
      };

  late MockClient mock;

  /// Pumps the BAS screen with: a GST-applicable sale, a GST-free sale, a
  /// GST-applicable purchase and a sale outside the quarter.
  Future<void> pumpScreen(WidgetTester tester) async {
    final String d = dateInPreviousQuarter();
    mock = MockClient((http.Request req) async {
      switch (req.url.path) {
        case '/transactions':
          return http.Response(
              jsonEncode([
                txn('t1', 'credit', 'gst', 100, 1100, 'R-001', d),
                txn('t2', 'credit', 'free', 0, 500, 'R-002', d),
                txn('t3', 'debit', 'gst', 30, 330, 'P-001', d),
                txn('t4', 'credit', 'gst', 900, 9900, 'R-OLD', '2000-01-15'),
              ]),
              200);
        case '/general-ledger':
          return http.Response(
              jsonEncode([
                {
                  'id': 'gst',
                  'label': 'Sales',
                  'description': '',
                  'gstApplicable': true,
                  'direction': 'moneyIn',
                },
                {
                  'id': 'free',
                  'label': 'Donations',
                  'description': '',
                  'gstApplicable': false,
                  'direction': 'moneyIn',
                },
              ]),
              200);
        case '/contacts':
          return http.Response(
              jsonEncode([
                {
                  'id': 'c1',
                  'name': 'Acme Pty Ltd',
                  'contactType': 'company',
                  'gstRegistered': true,
                },
              ]),
              200);
      }
      return http.Response('not found', 404);
    });

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      final ApiClient api = ApiClient(baseUrl: '', getToken: () => null);
      await tester.pumpWidget(ChangeNotifierProvider<ReferenceDataCache>(
        create: (_) => ReferenceDataCache(api),
        child: const MaterialApp(home: Scaffold(body: BasReportScreen())),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }, () => mock);
  }

  group('BasReportScreen drill-down', () {
    testWidgets('G1 lists every sale in the quarter at its total',
        (WidgetTester tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act
      await tester.tap(find.text('Total sales'));
      await tester.pumpAndSettle();

      // Assert
      final Finder dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('R-001')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('R-002')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('P-001')),
          findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('R-OLD')),
          findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('\$16.00')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('Acme Pty Ltd')),
          findsNWidgets(2));
    });

    testWidgets('1A lists only GST-applicable sales at their GST',
        (WidgetTester tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act
      await tester.tap(find.text('GST on sales'));
      await tester.pumpAndSettle();

      // Assert
      final Finder dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('R-001')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('R-002')),
          findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('\$1.00')),
          findsNWidgets(2)); // the line and the total
    });

    testWidgets('1B lists only GST-applicable purchases at their GST',
        (WidgetTester tester) async {
      // Arrange
      await pumpScreen(tester);

      // Act
      await tester.tap(find.text('GST on purchases'));
      await tester.pumpAndSettle();

      // Assert
      final Finder dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('P-001')),
          findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('R-001')),
          findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('\$0.30')),
          findsNWidgets(2));
    });
  });
}
