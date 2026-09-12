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

import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/services/i_o365_mailbox_service.dart';
import 'package:shedbooks_server/infrastructure/services/exchange_online_mailbox_service.dart';

void main() {
  const tEntityId = 'entity-1';
  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'club.onmicrosoft.com',
    clientId: 'client-guid',
    certificatePfxBase64: base64Encode(utf8.encode('fake-pfx-bytes')),
    certificatePassword: 'cert-password',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  String argAfter(List<String> args, String flag) =>
      args[args.indexOf(flag) + 1];

  group('ExchangeOnlineMailboxService.listAvailableLicenses', () {
    test('writes the certificate and config, then parses the license list',
        () async {
      // Arrange
      final sut = ExchangeOnlineMailboxService(
        listLicensesScriptPath: 'scripts/list_o365_licenses.ps1',
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            final configPath = argAfter(arguments, '-ConfigPath');
            final config =
                jsonDecode(await File(configPath).readAsString()) as Map;
            expect(config['tenantId'], equals('club.onmicrosoft.com'));
            expect(config['appId'], equals('client-guid'));
            expect(config['certificatePassword'], equals('cert-password'));
            await File(outputPath).writeAsString(jsonEncode({
              'licenses': [
                {'skuId': 'sku-1', 'skuPartNumber': 'SPB', 'availableUnits': 3},
              ]
            }));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act
      final result = await sut.listAvailableLicenses(settings: tSettings);

      // Assert
      expect(result, hasLength(1));
      expect(result.single.skuId, 'sku-1');
      expect(result.single.skuPartNumber, 'SPB');
      expect(result.single.availableUnits, 3);
    });

    test('throws O365MailboxException on a non-zero exit code', () async {
      // Arrange
      final sut = ExchangeOnlineMailboxService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            return ProcessResult(0, 1, '', 'connect failed');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.listAvailableLicenses(settings: tSettings),
        throwsA(isA<O365MailboxException>()),
      );
    });

    test('throws O365MailboxException when pwsh cannot be launched', () async {
      // Arrange
      final sut = ExchangeOnlineMailboxService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            throw const ProcessException('pwsh', [], 'not found');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.listAvailableLicenses(settings: tSettings),
        throwsA(isA<O365MailboxException>()),
      );
    });

    test('throws O365MailboxException on timeout', () async {
      // Arrange
      final sut = ExchangeOnlineMailboxService(
        timeout: const Duration(milliseconds: 10),
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.listAvailableLicenses(settings: tSettings),
        throwsA(isA<O365MailboxException>()),
      );
    });
  });

  group('ExchangeOnlineMailboxService.createMailbox', () {
    Future<ExchangeOnlineMailboxService> serviceReturning(
        Map<String, dynamic> resultJson) async {
      return ExchangeOnlineMailboxService(
        createMailboxScriptPath: 'scripts/create_o365_mailbox.ps1',
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            final outputPath = argAfter(arguments, '-OutputPath');
            final configPath = argAfter(arguments, '-ConfigPath');
            final config =
                jsonDecode(await File(configPath).readAsString()) as Map;
            expect(config['localPart'], equals('jane.smith'));
            expect(config['temporaryPassword'], equals('Sup3r!Secret'));
            expect(config['licenseSkuId'], equals('sku-1'));
            await File(outputPath).writeAsString(jsonEncode(resultJson));
          }
          return ProcessResult(0, 0, '', '');
        },
      );
    }

    Future<O365MailboxCreateResult> act(ExchangeOnlineMailboxService sut) =>
        sut.createMailbox(
          settings: tSettings,
          firstName: 'Jane',
          lastName: 'Smith',
          localPart: 'jane.smith',
          temporaryPassword: 'Sup3r!Secret',
          licenseSkuId: 'sku-1',
        );

    test('returns a successful result when status is "created"', () async {
      // Arrange
      final sut = await serviceReturning(
          {'status': 'created', 'upn': 'jane.smith@club.onmicrosoft.com'});

      // Act
      final result = await act(sut);

      // Assert
      expect(result.upn, 'jane.smith@club.onmicrosoft.com');
      expect(result.licenseAssigned, isTrue);
      expect(result.licenseError, isNull);
    });

    test('reports licenseAssigned false when status is "created_license_failed"',
        () async {
      // Arrange
      final sut = await serviceReturning({
        'status': 'created_license_failed',
        'upn': 'jane.smith@club.onmicrosoft.com',
        'licenseError': 'seat taken',
      });

      // Act
      final result = await act(sut);

      // Assert
      expect(result.upn, 'jane.smith@club.onmicrosoft.com');
      expect(result.licenseAssigned, isFalse);
      expect(result.licenseError, 'seat taken');
    });

    test('throws O365MailboxConflictException when status is "already_exists"',
        () async {
      // Arrange
      final sut = await serviceReturning({
        'status': 'already_exists',
        'upn': 'jane.smith@club.onmicrosoft.com',
      });

      // Act / Assert
      expect(act(sut), throwsA(isA<O365MailboxConflictException>()));
    });

    test('throws O365MailboxException when status is "license_unavailable"',
        () async {
      // Arrange
      final sut = await serviceReturning({
        'status': 'license_unavailable',
        'upn': 'jane.smith@club.onmicrosoft.com',
      });

      // Act / Assert
      expect(act(sut), throwsA(isA<O365MailboxException>()));
    });

    test('throws O365MailboxException on a non-zero exit code', () async {
      // Arrange
      final sut = ExchangeOnlineMailboxService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            return ProcessResult(0, 1, '', 'connect failed');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(act(sut), throwsA(isA<O365MailboxException>()));
    });
  });
}
