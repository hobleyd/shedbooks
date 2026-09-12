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

import 'dart:math';

/// Generates one-time temporary passwords for newly created O365 mailbox
/// accounts (see `CreateMemberMailboxUseCase`). The password is handed to
/// the admin once in the API response and never persisted — this class
/// exists only to produce it.
class TemporaryPasswordGenerator {
  // Ambiguous-looking characters (0/O, 1/l/I) are excluded so a password
  // read aloud or hand-copied from a screen isn't misread.
  static const _lower = 'abcdefghjkmnpqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _symbols = '!@#%^&*-_+=';
  static const _all = _lower + _upper + _digits + _symbols;

  final Random _rng;

  TemporaryPasswordGenerator([Random? rng]) : _rng = rng ?? Random.secure();

  /// Generates a [length]-character password guaranteed to contain at
  /// least one lowercase letter, one uppercase letter, one digit, and one
  /// symbol — satisfying typical Entra ID password-complexity policy.
  String generate({int length = 16}) {
    if (length < 4) {
      throw ArgumentError.value(length, 'length',
          'must be at least 4 to include one of each required character class');
    }
    final chars = <String>[
      _lower[_rng.nextInt(_lower.length)],
      _upper[_rng.nextInt(_upper.length)],
      _digits[_rng.nextInt(_digits.length)],
      _symbols[_rng.nextInt(_symbols.length)],
      for (var i = 4; i < length; i++) _all[_rng.nextInt(_all.length)],
    ];
    chars.shuffle(_rng);
    return chars.join();
  }
}
