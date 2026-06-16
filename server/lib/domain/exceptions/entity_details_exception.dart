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

/// Base class for all entity details domain exceptions.
sealed class EntityDetailsException implements Exception {
  final String message;
  const EntityDetailsException(this.message);

  @override
  String toString() => message;
}

/// Thrown when no entity details have been saved for the entity yet.
final class EntityDetailsNotFoundException extends EntityDetailsException {
  const EntityDetailsNotFoundException(String entityId)
      : super('Entity details not found for: $entityId');
}

/// Thrown when input data fails domain validation.
final class EntityDetailsValidationException extends EntityDetailsException {
  const EntityDetailsValidationException(super.message);
}
