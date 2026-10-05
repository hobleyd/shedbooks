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

import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/member_entry.dart';

void main() {
  group('MemberEntry.fromJson', () {
    Map<String, dynamic> json(Object? role) => <String, dynamic>{
          'id': 'm1',
          'firstName': 'Ada',
          'lastName': 'Lovelace',
          'shedbooksAppRole': role,
          'etag': 'e1',
        };

    test('keeps an assigned role', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json('viewer'));

      // Assert
      expect(sut.shedbooksAppRole, 'viewer');
    });

    test('treats an empty-string role as no access', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json(''));

      // Assert
      expect(sut.shedbooksAppRole, isNull);
    });

    test('treats a null role as no access', () {
      // Arrange / Act
      final MemberEntry sut = MemberEntry.fromJson(json(null));

      // Assert
      expect(sut.shedbooksAppRole, isNull);
    });
  });
}
