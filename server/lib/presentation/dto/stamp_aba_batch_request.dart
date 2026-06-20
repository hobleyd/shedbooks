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

/// Request body for POST /transactions/aba-batch.
class StampAbaBatchRequest {
  final List<String> transactionIds;
  final String batchName;

  const StampAbaBatchRequest({
    required this.transactionIds,
    required this.batchName,
  });

  factory StampAbaBatchRequest.fromJson(Map<String, dynamic> json) {
    final ids = json['transactionIds'];
    if (ids is! List) {
      throw const FormatException('transactionIds must be an array');
    }
    final batchName = json['batchName'];
    if (batchName is! String || batchName.isEmpty) {
      throw const FormatException('batchName must be a non-empty string');
    }
    return StampAbaBatchRequest(
      transactionIds: ids.cast<String>(),
      batchName: batchName,
    );
  }
}
