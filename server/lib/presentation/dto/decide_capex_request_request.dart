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

import '../../domain/enums/capex_request_status.dart';

/// Deserialised request body for POST /capex-requests/:id/decision.
class DecideCapexRequestRequest {
  final CapexRequestStatus status;
  final String decisionByName;
  final String? decisionNotes;

  const DecideCapexRequestRequest({
    required this.status,
    required this.decisionByName,
    this.decisionNotes,
  });

  factory DecideCapexRequestRequest.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'];
    if (statusRaw is! String ||
        (statusRaw != 'approved' && statusRaw != 'rejected')) {
      throw const FormatException('status must be "approved" or "rejected"');
    }
    final decisionByName = json['decisionByName'];
    if (decisionByName is! String || decisionByName.trim().isEmpty) {
      throw const FormatException('decisionByName must be a non-empty string');
    }
    final decisionNotesRaw = json['decisionNotes'];
    return DecideCapexRequestRequest(
      status: CapexRequestStatus.fromValue(statusRaw),
      decisionByName: decisionByName,
      decisionNotes: decisionNotesRaw is String ? decisionNotesRaw : null,
    );
  }
}
