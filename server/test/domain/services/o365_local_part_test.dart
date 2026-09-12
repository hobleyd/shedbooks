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

import 'package:shedbooks_server/domain/services/o365_local_part.dart';

void main() {
  group('buildO365LocalPart', () {
    test('joins a simple first and last name with a dot', () {
      // Act
      final result = buildO365LocalPart(firstName: 'Jane', lastName: 'Smith');

      // Assert
      expect(result, 'jane.smith');
    });

    test('strips an apostrophe from a surname', () {
      // Act
      final result = buildO365LocalPart(firstName: 'Conor', lastName: "O'Brien");

      // Assert
      expect(result, 'conor.obrien');
    });

    test('strips spaces from a multi-word surname', () {
      // Act
      final result =
          buildO365LocalPart(firstName: 'Hans', lastName: 'van der Berg');

      // Assert
      expect(result, 'hans.vanderberg');
    });

    test('strips a hyphen from a double-barrelled first name', () {
      // Act
      final result = buildO365LocalPart(firstName: 'Mary-Jane', lastName: 'Doe');

      // Assert
      expect(result, 'maryjane.doe');
    });

    test('strips diacritics from an accented name', () {
      // Act
      final result = buildO365LocalPart(firstName: 'José', lastName: 'Müller');

      // Assert
      expect(result, 'jose.muller');
    });

    test('uses only the surname when the first name is empty', () {
      // Act
      final result = buildO365LocalPart(firstName: '', lastName: 'Smith');

      // Assert
      expect(result, 'smith');
    });

    test('uses only the first name when the surname is empty', () {
      // Act
      final result = buildO365LocalPart(firstName: 'Jane', lastName: '');

      // Assert
      expect(result, 'jane');
    });

    test('throws when both names normalize to nothing', () {
      // Act / Assert
      expect(
        () => buildO365LocalPart(firstName: '...', lastName: '???'),
        throwsA(isA<O365LocalPartException>()),
      );
    });

    test('lowercases and strips punctuation/spaces but keeps digits', () {
      // Act
      final result =
          buildO365LocalPart(firstName: 'JOHN', lastName: 'St. Clair-Jones 3rd');

      // Assert
      expect(result, 'john.stclairjones3rd');
    });
  });
}
