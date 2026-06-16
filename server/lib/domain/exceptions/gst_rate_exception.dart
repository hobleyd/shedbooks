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

/// Base class for all GST rate domain exceptions.
sealed class GstRateException implements Exception {
  final String message;
  const GstRateException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested GST rate does not exist (or is deleted).
final class GstRateNotFoundException extends GstRateException {
  final String id;
  const GstRateNotFoundException(this.id)
      : super('GST rate not found: $id');
}

/// Thrown when no rate is effective at the requested date.
final class GstRateNotEffectiveException extends GstRateException {
  final DateTime date;
  GstRateNotEffectiveException(this.date)
      : super('No GST rate is effective at ${date.toIso8601String()}');
}

/// Thrown when a rate with the same effective-from date already exists.
final class GstRateDuplicateEffectiveDateException extends GstRateException {
  final DateTime effectiveFrom;
  GstRateDuplicateEffectiveDateException(this.effectiveFrom)
      : super(
          'A GST rate already exists with effective date '
          '${effectiveFrom.toIso8601String()}',
        );
}

/// Thrown when input data fails domain validation.
final class GstRateValidationException extends GstRateException {
  const GstRateValidationException(super.message);
}
