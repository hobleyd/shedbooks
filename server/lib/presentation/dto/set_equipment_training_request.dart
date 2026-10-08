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

/// Request DTO for `PUT /members/:id/equipment-training`.
class SetEquipmentTrainingRequest {
  /// The complete set of asset ids the member is trained on.
  final Set<String> assetIds;

  /// The date to record against newly ticked equipment (the caller's local
  /// "today"); null means use the server's current date.
  final DateTime? trainedOn;

  const SetEquipmentTrainingRequest({required this.assetIds, this.trainedOn});

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Parses and validates the request body.
  ///
  /// Throws [FormatException] if `assetIds` is not an array of UUID strings
  /// or `trainedOn` is not a `YYYY-MM-DD` date.
  factory SetEquipmentTrainingRequest.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['assetIds'];
    if (raw is! List) {
      throw const FormatException('assetIds must be an array');
    }
    final Set<String> ids = {};
    for (final Object? v in raw) {
      if (v is! String || !_uuid.hasMatch(v)) {
        throw const FormatException('assetIds must contain only UUID strings');
      }
      ids.add(v.toLowerCase());
    }

    final Object? rawDate = json['trainedOn'];
    DateTime? trainedOn;
    if (rawDate != null) {
      final DateTime? parsed = rawDate is String &&
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)
          ? DateTime.tryParse(rawDate)
          : null;
      if (parsed == null) {
        throw const FormatException('trainedOn must be a YYYY-MM-DD date');
      }
      trainedOn = parsed;
    }
    return SetEquipmentTrainingRequest(assetIds: ids, trainedOn: trainedOn);
  }
}
