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

/// How a Money-Out payment is sent to the bank. The enum names match the
/// server's `PaymentMethod` and are sent over the API as-is.
enum PaymentMethod {
  /// Paid to the contact's BSB / account number via the ABA upload file.
  directDebit('Direct Debit'),

  /// Paid to the contact's BPAY biller via the CommBiz BPAY upload file.
  bpay('BPAY');

  /// Name shown in the UI.
  final String label;

  const PaymentMethod(this.label);

  /// Parses an API value, defaulting to [directDebit] for a missing or
  /// unrecognised one (e.g. a response from a server older than migration 067).
  static PaymentMethod fromJson(Object? value) => PaymentMethod.values
      .firstWhere((PaymentMethod m) => m.name == value, orElse: () => directDebit);
}
