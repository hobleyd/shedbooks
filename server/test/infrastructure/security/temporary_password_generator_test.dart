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

import 'package:test/test.dart';

import 'package:shedbooks_server/infrastructure/security/temporary_password_generator.dart';

void main() {
  group('TemporaryPasswordGenerator', () {
    late TemporaryPasswordGenerator sut;

    setUp(() {
      sut = TemporaryPasswordGenerator();
    });

    test('generates a password of the default length', () {
      // Act
      final password = sut.generate();

      // Assert
      expect(password.length, 16);
    });

    test('generates a password of a requested length', () {
      // Act
      final password = sut.generate(length: 24);

      // Assert
      expect(password.length, 24);
    });

    test('throws for a length too short to fit every character class', () {
      // Act / Assert
      expect(() => sut.generate(length: 3), throwsArgumentError);
    });

    test('always contains at least one lowercase, uppercase, digit, and symbol', () {
      // Act / Assert — run many times since class placement is randomized.
      for (var i = 0; i < 200; i++) {
        final password = sut.generate();
        expect(password, matches(RegExp(r'[a-z]')));
        expect(password, matches(RegExp(r'[A-Z]')));
        expect(password, matches(RegExp(r'[0-9]')));
        expect(password, matches(RegExp(r'[!@#%^&*\-_+=]')));
      }
    });

    test('never contains ambiguous-looking characters (0, O, 1, l, I)', () {
      // Act / Assert
      for (var i = 0; i < 200; i++) {
        final password = sut.generate();
        expect(password, isNot(contains('0')));
        expect(password, isNot(contains('O')));
        expect(password, isNot(contains('1')));
        expect(password, isNot(contains('l')));
        expect(password, isNot(contains('I')));
      }
    });

    test('does not repeat the same password across calls', () {
      // Act
      final passwords = List.generate(50, (_) => sut.generate());

      // Assert
      expect(passwords.toSet().length, 50);
    });
  });
}
