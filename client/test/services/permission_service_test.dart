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
import 'package:shedbooks_client/models/permission_action.dart';
import 'package:shedbooks_client/models/permission_page.dart';
import 'package:shedbooks_client/services/api_client.dart';
import 'package:shedbooks_client/services/permission_service.dart';

void main() {
  // No privilege is granted by omission: before a successful load (or if one
  // never succeeds), every page/action must resolve to false — the same
  // "viewer by omission" stance as AppRole.fromList / the server's
  // roleFromRequest. The server's route guards remain the actual
  // enforcement point regardless; this only governs client-side UI.
  group('PermissionService fail-closed defaults', () {
    late PermissionService service;

    setUp(() {
      service = PermissionService(ApiClient(baseUrl: '', getToken: () => null));
    });

    test('isLoaded is false before any load', () {
      expect(service.isLoaded, isFalse);
    });

    test('canReadPage is false for every page before load', () {
      for (final page in PermissionPage.values) {
        expect(service.canReadPage(page), isFalse, reason: page.key);
      }
    });

    test('canWritePage is false for every page before load', () {
      for (final page in PermissionPage.values) {
        expect(service.canWritePage(page), isFalse, reason: page.key);
      }
    });

    test('canPerform is false for every action before load (falls back to '
        'canWritePage, itself false)', () {
      for (final action in PermissionAction.values) {
        expect(service.canPerform(action), isFalse, reason: action.key);
      }
    });

    test('reset clears isLoaded', () {
      service.reset();
      expect(service.isLoaded, isFalse);
    });
  });

  group('PermissionPage / PermissionAction registries', () {
    test('every page key is unique', () {
      final keys = PermissionPage.values.map((p) => p.key).toSet();
      expect(keys.length, equals(PermissionPage.values.length));
    });

    test('every action key is unique', () {
      final keys = PermissionAction.values.map((a) => a.key).toSet();
      expect(keys.length, equals(PermissionAction.values.length));
    });

    test('fromKey round-trips every registered page', () {
      for (final page in PermissionPage.values) {
        expect(PermissionPage.fromKey(page.key), equals(page));
      }
    });

    test('fromKey round-trips every registered action', () {
      for (final action in PermissionAction.values) {
        expect(PermissionAction.fromKey(action.key), equals(action));
      }
    });
  });
}
