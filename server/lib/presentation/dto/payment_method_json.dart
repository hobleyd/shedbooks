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

import '../../domain/entities/transaction.dart';

/// Parses the optional `paymentMethod` field of a transaction request body.
///
/// Returns null when [raw] is absent — create requests then default to
/// [PaymentMethod.directDebit] and update requests keep the existing value.
/// Throws [FormatException] when [raw] is not one of the [PaymentMethod] names.
PaymentMethod? parsePaymentMethod(Object? raw) {
  if (raw == null) return null;
  if (raw is String) {
    for (final PaymentMethod method in PaymentMethod.values) {
      if (method.name == raw) return method;
    }
  }
  throw FormatException(
    'paymentMethod must be one of: ${PaymentMethod.values.map((e) => e.name).join(', ')}',
  );
}
