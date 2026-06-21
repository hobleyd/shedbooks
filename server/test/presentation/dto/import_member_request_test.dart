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

import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';
import 'package:shedbooks_server/presentation/dto/import_member_request.dart';

/// Parses a single-item import JSON array and returns the first
/// [MemberImportData] from the result.
MemberImportData _parse(Map<String, dynamic> json) =>
    ImportMembersRequest.fromJson([json]).members.first;

void main() {
  group('ImportMembersRequest — emergency contact splitting', () {
    test('name only: full string goes to name, phone is null', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': 'Fay'});
      expect(m.emergencyContactName, equals('Fay'));
      expect(m.emergencyContactPhone, isNull);
    });

    test('name then phone: phone extracted, name is remainder', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': 'Rhonda 0422363712'});
      expect(m.emergencyContactName, equals('Rhonda'));
      expect(m.emergencyContactPhone, equals('0422363712'));
    });

    test('name then large whitespace then phone', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': 'Kaye                            0419795788'});
      expect(m.emergencyContactName, equals('Kaye'));
      expect(m.emergencyContactPhone, equals('0419795788'));
    });

    test('name role phone: role stays in name, phone extracted', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': 'Leonie Buckland 0412995758 Sister'});
      expect(m.emergencyContactName, equals('Leonie Buckland Sister'));
      expect(m.emergencyContactPhone, equals('0412995758'));
    });

    test('name phone role: role stays in name, phone extracted', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': 'Jenene Splinter 0408618935 Wife'});
      expect(m.emergencyContactName, equals('Jenene Splinter Wife'));
      expect(m.emergencyContactPhone, equals('0408618935'));
    });

    test('name with parenthesised role then phone', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': 'Barbara (Mum) 0741265026'});
      expect(m.emergencyContactName, equals('Barbara (Mum)'));
      expect(m.emergencyContactPhone, equals('0741265026'));
    });

    test('null emergencyContact leaves both fields null', () {
      final m = _parse({'lastName': 'Smith', 'emergencyContact': null});
      expect(m.emergencyContactName, isNull);
      expect(m.emergencyContactPhone, isNull);
    });

    test('explicit emergencyContactName/Phone fields take precedence over emergencyContact', () {
      final m = _parse({
        'lastName': 'Smith',
        'emergencyContactName': 'Alice',
        'emergencyContactPhone': '0412000000',
        'emergencyContact': 'Should be ignored 0499999999',
      });
      expect(m.emergencyContactName, equals('Alice'));
      expect(m.emergencyContactPhone, equals('0412000000'));
    });
  });
}
