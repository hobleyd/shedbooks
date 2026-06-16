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

/// Base class for all bank account domain exceptions.
sealed class BankAccountException implements Exception {
  final String message;
  const BankAccountException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a requested bank account does not exist or has been deleted.
final class BankAccountNotFoundException extends BankAccountException {
  final String id;
  const BankAccountNotFoundException(this.id)
      : super('Bank account not found: $id');
}

/// Thrown when input data fails domain validation.
final class BankAccountValidationException extends BankAccountException {
  const BankAccountValidationException(super.message);
}

/// Thrown when an operation is attempted on a system-managed account.
final class BankAccountSystemException extends BankAccountException {
  const BankAccountSystemException()
      : super('System accounts cannot be modified or deleted');
}
