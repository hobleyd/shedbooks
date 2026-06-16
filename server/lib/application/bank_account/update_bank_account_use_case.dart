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

import '../../domain/entities/bank_account.dart';
import '../../domain/exceptions/bank_account_exception.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Updates an existing bank account.
class UpdateBankAccountUseCase {
  final IBankAccountRepository _repository;

  const UpdateBankAccountUseCase(this._repository);

  /// Throws [BankAccountValidationException] on invalid input.
  /// Throws [BankAccountNotFoundException] when the account does not exist.
  Future<BankAccount> execute({
    required String id,
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  }) async {
    final trimmedBank = bankName.trim();
    final trimmedName = accountName.trim();
    final trimmedBsb = bsb.replaceAll('-', '').trim();
    final trimmedAccNum = accountNumber.trim();
    final trimmedCurrency = currency.trim().toUpperCase();

    if (trimmedBank.isEmpty) {
      throw const BankAccountValidationException('Bank name must not be empty');
    }
    if (trimmedName.isEmpty) {
      throw const BankAccountValidationException(
          'Account name must not be empty');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(trimmedBsb)) {
      throw const BankAccountValidationException('BSB must be exactly 6 digits');
    }
    if (!RegExp(r'^\d{6,10}$').hasMatch(trimmedAccNum)) {
      throw const BankAccountValidationException(
          'Account number must be 6 to 10 digits');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(trimmedCurrency)) {
      throw const BankAccountValidationException(
          'Currency must be a 3-letter ISO code');
    }

    return _repository.update(
      id: id,
      entityId: entityId,
      bankName: trimmedBank,
      accountName: trimmedName,
      bsb: trimmedBsb,
      accountNumber: trimmedAccNum,
      accountType: accountType,
      currency: trimmedCurrency,
    );
  }
}
