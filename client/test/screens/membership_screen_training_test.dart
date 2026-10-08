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
import 'package:shedbooks_client/auth/auth_state.dart';
import 'package:shedbooks_client/screens/membership_screen.dart';
import 'package:shedbooks_client/services/api_client.dart';
import 'package:shedbooks_client/services/navigation_guard.dart';
import 'package:shedbooks_client/services/permission_service.dart';

void main() {
  const Map<String, dynamic> bandSaw = {
    'assetId': 'a-saw',
    'assetNo': '2026-W-0002',
    'section': 'Wood Shop',
    'description': 'Band Saw - 14 inch',
    'brand': null,
  };
  const Map<String, dynamic> drillPress = {
    'assetId': 'a-drill',
    'assetNo': '2026-W-0003',
    'section': 'Wood Shop',
    'description': 'Drill Press - Bench',
    'brand': 'Millers Falls',
  };
  const Map<String, dynamic> lathe = {
    'assetId': 'a-lathe',
    'assetNo': '2026-M-001',
    'section': 'Metal Shop',
    'description': 'Lathe',
    'brand': null,
  };

  /// Requests the screen sent, as `METHOD path` → decoded JSON body.
  late List<(String, Object?)> sent;

  /// The fake server; later interactions must run under it too.
  late MockClient mock;

  /// Pumps the Members screen for a user with members write access and one
  /// member (already trained on the band saw, with a legacy metalworking
  /// induction date).
  Future<void> pumpScreen(WidgetTester tester,
      {Size size = const Size(1800, 1000)}) async {
    sent = [];
    mock = MockClient((http.Request req) async {
      final String path = req.url.path;
      if (req.method != 'GET') {
        sent.add(('${req.method} $path', jsonDecode(req.body)));
      }
      if (path == '/roles/effective') {
        return http.Response(
            jsonEncode({
              'pages': {
                'members': {'canRead': true, 'canWrite': true},
              },
              'actions': <String, dynamic>{},
            }),
            200);
      }
      if (path == '/members/training-equipment') {
        return http.Response(jsonEncode([bandSaw, drillPress, lathe]), 200);
      }
      if (path == '/members' && req.method == 'GET') {
        return http.Response(
            jsonEncode([
              {
                'id': 'm1',
                'firstName': 'Ada',
                'lastName': 'Lovelace',
                'metalworkingInduction': '2024-03-05',
                'etag': 'e1',
                'equipmentTraining': [
                  {...bandSaw, 'trainedOn': '2026-10-01'},
                ],
              },
            ]),
            200);
      }
      return http.Response(jsonEncode({'id': 'm1'}), 200);
    });

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      final ApiClient api = ApiClient(baseUrl: '', getToken: () => null);
      final PermissionService permissions = PermissionService(api);
      await tester.runAsync(permissions.refresh);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
          ChangeNotifierProvider<PermissionService>.value(value: permissions),
          ChangeNotifierProvider<NavigationGuard>(
              create: (_) => NavigationGuard()),
        ],
        child: const MaterialApp(home: MembershipScreen()),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }, () => mock);
  }

  group('MembershipScreen equipment training', () {
    testWidgets(
        'table shows a pill per trained item with its date, plus the legacy '
        'induction date', (WidgetTester tester) async {
      // Arrange / Act
      await pumpScreen(tester);

      // Assert
      expect(find.text('Band Saw - 14 inch'), findsOneWidget);
      expect(find.text('01/10/2026'), findsOneWidget);
      expect(find.text('Induction'), findsOneWidget);
      expect(find.text('05/03/2024'), findsOneWidget);
      expect(find.text('Drill Press - Bench'), findsNothing);
      // Pills are display-only: no tap target wraps the equipment name.
      expect(
        find.ancestor(
            of: find.text('Band Saw - 14 inch'), matching: find.byType(InkWell)),
        findsNothing,
      );
    });

    testWidgets(
        'table has no Role column and fits a 1100-wide viewport without '
        'horizontal scrolling', (WidgetTester tester) async {
      // Arrange / Act
      await pumpScreen(tester, size: const Size(1100, 800));

      // Assert
      expect(find.text('Role'), findsNothing);
      expect(find.text('Woodworking'), findsOneWidget);
      final ScrollableState horizontal = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((s) => s.position.axis == Axis.horizontal);
      expect(horizontal.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ticking equipment in the Woodworking dropdown and saving sends the '
        'full trained set with today\'s date', (WidgetTester tester) async {
      // Arrange
      await pumpScreen(tester);
      await http.runWithClient(() async {
        await tester.tap(find.byTooltip('Edit'));
        await tester.pumpAndSettle();
        expect(find.text('1 of 2 trained'), findsOneWidget);
        expect(find.text('Select equipment'), findsOneWidget);

        // Act
        await tester.tap(find.text('1 of 2 trained'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxMenuButton), findsNWidgets(2));
        await tester.tap(find.textContaining('Drill Press - Bench'));
        await tester.pumpAndSettle();
        expect(find.text('2 of 2 trained'), findsOneWidget);
        await tester.tapAt(const Offset(1700, 900)); // dismiss the menu
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
      }, () => mock);

      // Assert
      final DateTime now = DateTime.now();
      final String today = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(sent.map((r) => r.$1),
          ['PUT /members/m1', 'PUT /members/m1/equipment-training']);
      final Map<String, dynamic> memberBody =
          sent[0].$2! as Map<String, dynamic>;
      expect(memberBody['metalworkingInduction'], '2024-03-05',
          reason: 'legacy induction date must survive the full-replace PUT');
      final Map<String, dynamic> trainingBody =
          sent[1].$2! as Map<String, dynamic>;
      expect(trainingBody['assetIds'], unorderedEquals(['a-saw', 'a-drill']));
      expect(trainingBody['trainedOn'], today);
    });
  });
}
