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

import 'package:flutter/foundation.dart';

import '../models/permission_action.dart';
import '../models/permission_page.dart';
import 'api_client.dart';

/// Caller's own resolved page/action permissions (`GET /roles/effective`),
/// shared across the app via [ChangeNotifier] the same way
/// [ReferenceDataCache] shares reference data.
///
/// This is a UI convenience only — no privilege is granted by omission here:
/// every getter defaults to false until a successful load completes, and
/// the server's route guards (`requirePagePermission`/`requireActionPermission`)
/// remain the actual enforcement point regardless of what this class reports.
class PermissionService extends ChangeNotifier {
  final ApiClient _apiClient;

  PermissionService(this._apiClient);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Bumped by [reset]; a load whose epoch no longer matches on completion
  /// discards its result rather than writing a previous/other session's
  /// permissions into the cache after logout.
  int _epoch = 0;

  Map<PermissionPage, ({bool canRead, bool canWrite})> _pages = {};
  Map<PermissionAction, bool> _actions = {};

  bool canReadPage(PermissionPage page) => _pages[page]?.canRead ?? false;

  bool canWritePage(PermissionPage page) => _pages[page]?.canWrite ?? false;

  bool canPerform(PermissionAction action) =>
      _actions[action] ?? canWritePage(action.page);

  Future<void> ensureLoaded() => _loaded ? Future.value() : refresh();

  /// Re-fetches from the server. Called once after login (see main.dart)
  /// and again immediately after a Roles-page save, so testing a permission
  /// change doesn't require signing out and back in.
  Future<void> refresh() async {
    final epoch = _epoch;
    try {
      final res = await _apiClient.get('/roles/effective');
      if (epoch != _epoch) return;
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final pagesJson = json['pages'] as Map<String, dynamic>;
      final actionsJson = json['actions'] as Map<String, dynamic>;

      _pages = {
        for (final page in PermissionPage.values)
          if (pagesJson[page.key] is Map)
            page: (
              canRead: (pagesJson[page.key] as Map)['canRead'] as bool,
              canWrite: (pagesJson[page.key] as Map)['canWrite'] as bool,
            ),
      };
      _actions = {
        for (final action in PermissionAction.values)
          if (actionsJson[action.key] is bool) action: actionsJson[action.key] as bool,
      };
      _loaded = true;
    } catch (_) {
      // Keep whatever was previously loaded (or the fail-closed defaults if
      // this was the first attempt) rather than throwing during navigation.
    }
    notifyListeners();
  }

  /// Clears cached permissions and bumps the epoch so an in-flight load from
  /// a previous session cannot write stale/cross-tenant data after logout.
  void reset() {
    _epoch++;
    _loaded = false;
    _pages = {};
    _actions = {};
    notifyListeners();
  }
}
