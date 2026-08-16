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

import '../../application/o365/sync_members_to_o365_use_case.dart';

/// Response DTO for a `POST /members/sync-o365` run.
class O365SyncResultResponse {
  final int synced;
  final int failed;
  final int remaining;

  const O365SyncResultResponse({
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  factory O365SyncResultResponse.fromResult(O365SyncBatchResult r) =>
      O365SyncResultResponse(
        synced: r.synced,
        failed: r.failed,
        remaining: r.remaining,
      );

  Map<String, dynamic> toJson() => {
        'synced': synced,
        'failed': failed,
        'remaining': remaining,
      };

  String toJsonString() => jsonEncode(toJson());
}
