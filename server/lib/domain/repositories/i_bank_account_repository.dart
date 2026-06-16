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

import '../entities/bank_account.dart';

/// Repository interface for bank account persistence.
abstract class IBankAccountRepository {
  Future<BankAccount> create({
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  });

  Future<BankAccount?> findById(String id, {required String entityId});

  Future<List<BankAccount>> findAll({required String entityId});

  Future<BankAccount> update({
    required String id,
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  });

  Future<void> delete(String id, {required String entityId});

  /// Updates the sort_order of accounts to match the given [ids] sequence.
  Future<void> reorder({required String entityId, required List<String> ids});

  /// Ensures the system Cash account exists for [entityId], creating it if absent.
  Future<void> ensureCashAccount({required String entityId});
}
