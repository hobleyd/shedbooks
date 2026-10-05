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

import '../../domain/entities/o365_sync_settings.dart';
import '../../domain/exceptions/app_role_exception.dart';
import '../../domain/services/i_graph_app_role_service.dart';
import 'process_runner.dart';

/// Grants/revokes Shedbooks app roles via `manage_app_role_assignment.ps1`,
/// under certificate-based app-only Microsoft Graph auth — same credential
/// shape as [ExchangeOnlineMailboxService][1], reused rather than duplicated.
///
/// [1]: exchange_online_mailbox_service.dart
class GraphAppRoleAssignmentService implements IGraphAppRoleService {
  final ProcessRunner _runProcess;
  final String _scriptPath;
  final Duration _timeout;

  GraphAppRoleAssignmentService({
    ProcessRunner? runProcess,
    String? scriptPath,
    // A single Graph connect plus a handful of appRoleAssignment calls —
    // no Exchange session, no module imports beyond Graph auth/users, so
    // this budget is far smaller than ExchangeOnlineMailboxService's.
    Duration timeout = const Duration(seconds: 60),
  })  : _runProcess = runProcess ?? Process.run,
        _scriptPath = scriptPath ??
            Platform.environment['O365_MANAGE_APP_ROLE_SCRIPT_PATH'] ??
            'scripts/manage_app_role_assignment.ps1',
        _timeout = timeout;

  @override
  Future<String?> setAppRole({
    required O365SyncSettings settings,
    required String resourceServicePrincipalId,
    required String targetUserId,
    required String? appRole,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('approle-');
    try {
      final certPath = '${tempDir.path}/cert.pfx';
      final configPath = '${tempDir.path}/config.json';
      final outputPath = '${tempDir.path}/results.json';

      await File(certPath).writeAsBytes(base64Decode(settings.certificatePfxBase64));
      await _restrictPermissions(certPath);

      final config = {
        'tenantId': settings.tenantId,
        'appId': settings.clientId,
        'certificatePath': certPath,
        'certificatePassword': settings.certificatePassword,
        'targetUserId': targetUserId,
        'resourceId': resourceServicePrincipalId,
        'appRole': appRole,
      };
      await File(configPath).writeAsString(jsonEncode(config));
      await _restrictPermissions(configPath);

      final ProcessResult result;
      try {
        result = await _runProcess('pwsh', [
          '-NoProfile',
          '-NonInteractive',
          '-File', _scriptPath,
          '-ConfigPath', configPath,
          '-OutputPath', outputPath,
        ]).timeout(_timeout);
      } on TimeoutException {
        throw GraphAppRoleException(
            'Managing the app role assignment timed out after $_timeout');
      } on ProcessException catch (e) {
        throw GraphAppRoleException(
            'Failed to launch Graph PowerShell session (PowerShell not available?): ${e.message}');
      }

      if (result.exitCode != 0) {
        throw GraphAppRoleException(
          'Graph session failed while managing the app role assignment '
          '(exit ${result.exitCode}): ${_snippet(result.stderr.toString())}',
        );
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw const GraphAppRoleException(
            'App role assignment produced no results file');
      }

      final decoded = jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;
      // An empty string means "no role" just as null does (PowerShell
      // serialises a [string] \$null as '').
      final String? role = decoded['role'] as String?;
      return role == null || role.isEmpty ? null : role;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }

  Future<void> _restrictPermissions(String path) async {
    final result = await _runProcess('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw const GraphAppRoleException(
          'Failed to restrict permissions on a temporary session file');
    }
  }

  // Graph error messages often carry a correlation/request id GUID and are
  // longer than the plain validation messages elsewhere in this codebase
  // budget for — the script now emits a single clean line (no PowerShell
  // Write-Error boilerplate, see manage_app_role_assignment.ps1's header),
  // so this budget is spent entirely on the message itself.
  String _snippet(String s) => s.length > 1000 ? '${s.substring(0, 1000)}...' : s;
}
