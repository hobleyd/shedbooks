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

/// Base class for all contact domain exceptions.
sealed class ContactException implements Exception {
  final String message;
  const ContactException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested contact does not exist (or is deleted).
final class ContactNotFoundException extends ContactException {
  final String id;
  const ContactNotFoundException(this.id)
      : super('Contact not found: $id');
}

/// Thrown when input data fails domain validation.
final class ContactValidationException extends ContactException {
  const ContactValidationException(super.message);
}

/// Thrown when attempting to delete a contact that still has active transactions.
final class ContactInUseException extends ContactException {
  const ContactInUseException(String id)
      : super('Contact $id cannot be deleted because it has transactions');
}
