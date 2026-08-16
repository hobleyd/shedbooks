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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/infrastructure/services/exchange_online_mail_contact_sync_service.dart';

void main() {
  const tEntityId = 'entity-1';
  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'tenant-guid',
    clientId: 'client-guid',
    certificatePfxBase64: base64Encode(utf8.encode('fake-pfx-bytes')),
    certificatePassword: 'cert-password',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Member member(String id, {String? existingContactId}) => Member(
        id: id,
        entityId: tEntityId,
        firstName: 'Ron',
        lastName: 'Anderson $id',
        email: 'ron$id@example.com',
        etag: 'etag-$id',
        o365ContactId: existingContactId,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  /// Finds the value following [flag] in a pwsh argument list, e.g. the
  /// path passed via `-OutputPath <path>`.
  String argAfter(List<String> args, String flag) =>
      args[args.indexOf(flag) + 1];

  group('ExchangeOnlineMailContactSyncService', () {
    test('writes the certificate and a JSON config, then parses results',
        () async {
      // Arrange
      final calls = <(String, List<String>)>[];
      final sut = ExchangeOnlineMailContactSyncService(
        scriptPath: 'scripts/sync_gal_contacts.ps1',
        runProcess: (executable, arguments) async {
          calls.add((executable, arguments));
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            final configPath = argAfter(arguments, '-ConfigPath');
            final config =
                jsonDecode(await File(configPath).readAsString()) as Map;
            expect(config['tenantId'], equals('tenant-guid'));
            expect(config['appId'], equals('client-guid'));
            expect(config['certificatePassword'], equals('cert-password'));
            await File(outputPath).writeAsString(jsonEncode({
              'results': [
                {'memberId': '1', 'contactId': 'gal-id-1', 'error': null},
              ]
            }));
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final results = await sut.upsertContacts(
        settings: tSettings,
        members: [member('1')],
      );

      // Assert
      expect(results, hasLength(1));
      expect(results.single.memberId, equals('1'));
      expect(results.single.contactId, equals('gal-id-1'));
      expect(results.single.succeeded, isTrue);
      final pwshCall = calls.firstWhere((c) => c.$1 == 'pwsh');
      expect(pwshCall.$2, contains('scripts/sync_gal_contacts.ps1'));
      // The certificate and config files must have had permissions restricted.
      expect(calls.where((c) => c.$1 == 'chmod'), hasLength(2));
    });

    test('returns an empty list without invoking any process for an empty batch',
        () async {
      // Arrange
      var invoked = false;
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          invoked = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final results = await sut.upsertContacts(settings: tSettings, members: []);

      // Assert
      expect(results, isEmpty);
      expect(invoked, isFalse);
    });

    test('reports per-member errors from the results file without throwing',
        () async {
      // Arrange
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            await File(outputPath).writeAsString(jsonEncode({
              'results': [
                {
                  'memberId': '1',
                  'contactId': null,
                  'error': 'Member has no email address',
                },
              ]
            }));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final results =
          await sut.upsertContacts(settings: tSettings, members: [member('1')]);

      // Assert
      expect(results.single.succeeded, isFalse);
      expect(results.single.error?.message,
          contains('Member has no email address'));
    });

    test('defensively accepts a bare results object for a single-member batch',
        () async {
      // Arrange — guards against a PowerShell serialization quirk where a
      // one-element array could be emitted as a bare object.
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            await File(outputPath).writeAsString(jsonEncode({
              'results': {'memberId': '1', 'contactId': 'gal-id-1', 'error': null}
            }));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final results =
          await sut.upsertContacts(settings: tSettings, members: [member('1')]);

      // Assert
      expect(results.single.contactId, equals('gal-id-1'));
    });

    test('throws O365ContactSyncException when the process exits non-zero '
        '(e.g. Connect-ExchangeOnline failed)', () async {
      // Arrange
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            return ProcessResult(0, 1, '', 'certificate rejected');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.upsertContacts(settings: tSettings, members: [member('1')]),
        throwsA(isA<O365ContactSyncException>()),
      );
    });

    test('throws O365ContactSyncException when pwsh itself cannot be launched',
        () async {
      // Arrange
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            throw const ProcessException('pwsh', [], 'No such file or directory');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.upsertContacts(settings: tSettings, members: [member('1')]),
        throwsA(isA<O365ContactSyncException>()),
      );
    });

    test('throws O365ContactSyncException instead of hanging when the '
        'process never completes and no partial results exist', () async {
      // Arrange
      final sut = ExchangeOnlineMailContactSyncService(
        timeout: const Duration(milliseconds: 50),
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            // Never completes — simulates a stalled Connect-ExchangeOnline.
            return Completer<ProcessResult>().future;
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      await expectLater(
        () => sut.upsertContacts(settings: tSettings, members: [member('1')]),
        throwsA(isA<O365ContactSyncException>()),
      );
    });

    test('recovers partial results after a timeout if the script had '
        'already checkpointed some members', () async {
      // Arrange — the script writes results incrementally, so a batch that
      // times out may still have a usable partial file on disk.
      final sut = ExchangeOnlineMailContactSyncService(
        timeout: const Duration(milliseconds: 50),
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            await File(outputPath).writeAsString(jsonEncode({
              'results': [
                {'memberId': '1', 'contactId': 'gal-id-1', 'error': null},
              ]
            }));
            return Completer<ProcessResult>().future; // then hangs
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final results = await sut.upsertContacts(
        settings: tSettings,
        members: [member('1'), member('2')],
      );

      // Assert
      final byId = {for (final r in results) r.memberId: r};
      expect(byId['1']!.contactId, equals('gal-id-1'));
      expect(byId['2']!.succeeded, isFalse);
    });

    test('reports a missing result for a member absent from the output',
        () async {
      // Arrange — the script itself never got to this member for some reason.
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            await File(outputPath)
                .writeAsString(jsonEncode({'results': <dynamic>[]}));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final results =
          await sut.upsertContacts(settings: tSettings, members: [member('1')]);

      // Assert
      expect(results.single.succeeded, isFalse);
      expect(results.single.error?.message, contains('No result returned'));
    });

    test('passes the existing contact id through for a previously synced member',
        () async {
      // Arrange
      Map<String, dynamic>? capturedConfig;
      final sut = ExchangeOnlineMailContactSyncService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final configPath = argAfter(arguments, '-ConfigPath');
            capturedConfig =
                jsonDecode(await File(configPath).readAsString()) as Map<String, dynamic>;
            final outputPath = argAfter(arguments, '-OutputPath');
            await File(outputPath).writeAsString(jsonEncode({
              'results': [
                {'memberId': '1', 'contactId': 'existing-gal-id', 'error': null},
              ]
            }));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      await sut.upsertContacts(
        settings: tSettings,
        members: [member('1', existingContactId: 'existing-gal-id')],
      );

      // Assert
      final members = capturedConfig!['members'] as List;
      expect((members.single as Map)['existingContactId'],
          equals('existing-gal-id'));
    });
  });
}
