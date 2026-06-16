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

/// Base class for all general ledger domain exceptions.
sealed class GeneralLedgerException implements Exception {
  final String message;
  const GeneralLedgerException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested general ledger account does not exist (or is deleted).
final class GeneralLedgerNotFoundException extends GeneralLedgerException {
  final String id;
  const GeneralLedgerNotFoundException(this.id)
      : super('General ledger account not found: $id');
}

/// Thrown when input data fails domain validation.
final class GeneralLedgerValidationException extends GeneralLedgerException {
  const GeneralLedgerValidationException(super.message);
}

/// Thrown when attempting to delete an account that has child accounts.
final class GeneralLedgerHasChildrenException extends GeneralLedgerException {
  final String id;
  const GeneralLedgerHasChildrenException(this.id)
      : super('General ledger account $id has child accounts and cannot be deleted');
}
