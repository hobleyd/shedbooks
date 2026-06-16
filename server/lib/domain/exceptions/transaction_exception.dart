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

/// Base class for all transaction domain exceptions.
sealed class TransactionException implements Exception {
  final String message;
  const TransactionException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested transaction does not exist (or is deleted).
final class TransactionNotFoundException extends TransactionException {
  final String id;
  const TransactionNotFoundException(this.id)
      : super('Transaction not found: $id');
}

/// Thrown when input data fails domain or referential validation.
final class TransactionValidationException extends TransactionException {
  const TransactionValidationException(super.message);
}
