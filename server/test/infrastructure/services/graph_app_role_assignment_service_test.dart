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
import 'package:shedbooks_server/domain/exceptions/app_role_exception.dart';
import 'package:shedbooks_server/infrastructure/services/graph_app_role_assignment_service.dart';

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

  GraphAppRoleAssignmentService serviceReturning(String? role) {
    return GraphAppRoleAssignmentService(
      scriptPath: 'scripts/manage_app_role_assignment.ps1',
      runProcess: (executable, arguments) async {
        if (executable == 'pwsh') {
          final outputPath = argAfter(arguments, '-OutputPath');
          final configPath = argAfter(arguments, '-ConfigPath');
          final config =
              jsonDecode(await File(configPath).readAsString()) as Map;
          expect(config['tenantId'], equals('club.onmicrosoft.com'));
          expect(config['appId'], equals('client-guid'));
          expect(config['targetUserId'], equals('jane.smith@club.onmicrosoft.com'));
          expect(config['resourceId'], equals('sp-object-id'));
          await File(outputPath).writeAsString(jsonEncode({'role': role}));
        }
        return ProcessResult(0, 0, '', '');
      },
    );
  }

  Future<String?> act(GraphAppRoleAssignmentService sut, String? appRole) =>
      sut.setAppRole(
        settings: tSettings,
        resourceServicePrincipalId: 'sp-object-id',
        targetUserId: 'jane.smith@club.onmicrosoft.com',
        appRole: appRole,
      );

  group('GraphAppRoleAssignmentService.setAppRole', () {
    test('writes the certificate and config, then returns the resulting role',
        () async {
      // Arrange
      final sut = serviceReturning('contributor');

      // Act
      final result = await act(sut, 'contributor');

      // Assert
      expect(result, 'contributor');
    });

    test('returns null when Graph reports no role assigned (revoked)',
        () async {
      // Arrange
      final sut = serviceReturning(null);

      // Act
      final result = await act(sut, null);

      // Assert
      expect(result, isNull);
    });

    test('returns null when the script reports an empty-string role',
        () async {
      // Arrange
      final sut = serviceReturning('');

      // Act
      final result = await act(sut, null);

      // Assert
      expect(result, isNull);
    });

    test('throws GraphAppRoleException on a non-zero exit code', () async {
      // Arrange
      final sut = GraphAppRoleAssignmentService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            return ProcessResult(0, 1, '', 'connect failed');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(act(sut, 'viewer'), throwsA(isA<GraphAppRoleException>()));
    });

    test('throws GraphAppRoleException when pwsh cannot be launched', () async {
      // Arrange
      final sut = GraphAppRoleAssignmentService(
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            throw const ProcessException('pwsh', [], 'not found');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(act(sut, 'viewer'), throwsA(isA<GraphAppRoleException>()));
    });

    test('throws GraphAppRoleException on timeout', () async {
      // Arrange
      final sut = GraphAppRoleAssignmentService(
        timeout: const Duration(milliseconds: 10),
        runProcess: (executable, arguments) async {
          if (executable == 'pwsh') {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(act(sut, 'viewer'), throwsA(isA<GraphAppRoleException>()));
    });

    test('throws GraphAppRoleException when no results file is produced',
        () async {
      // Arrange
      final sut = GraphAppRoleAssignmentService(
        runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
      );

      // Act / Assert
      expect(act(sut, 'viewer'), throwsA(isA<GraphAppRoleException>()));
    });
  });
}
