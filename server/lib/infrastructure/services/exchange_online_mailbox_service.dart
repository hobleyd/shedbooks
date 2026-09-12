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
import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/services/i_o365_mailbox_service.dart';
import 'process_runner.dart';

/// Creates tenant sign-in accounts and reports available licenses by
/// invoking `list_o365_licenses.ps1` / `create_o365_mailbox.ps1` under
/// Microsoft Graph and Exchange Online PowerShell (both certificate-based
/// app-only auth) — see those scripts' headers for why two separate
/// authentication surfaces are needed for one feature.
class ExchangeOnlineMailboxService implements IO365MailboxService {
  final ProcessRunner _runProcess;
  final String _listLicensesScriptPath;
  final String _createMailboxScriptPath;
  final Duration _timeout;

  ExchangeOnlineMailboxService({
    ProcessRunner? runProcess,
    String? listLicensesScriptPath,
    String? createMailboxScriptPath,
    // create_o365_mailbox.ps1 establishes two full sessions (Graph, then
    // Exchange) plus several module imports before it does anything — see
    // that script's header for the connect-count budget this is sized
    // against. Must stay comfortably under client/nginx.conf.template's
    // `proxy_read_timeout` for /api/, which is raised in step with this.
    Duration timeout = const Duration(seconds: 150),
  })  : _runProcess = runProcess ?? Process.run,
        _listLicensesScriptPath = listLicensesScriptPath ??
            Platform.environment['O365_LIST_LICENSES_SCRIPT_PATH'] ??
            'scripts/list_o365_licenses.ps1',
        _createMailboxScriptPath = createMailboxScriptPath ??
            Platform.environment['O365_CREATE_MAILBOX_SCRIPT_PATH'] ??
            'scripts/create_o365_mailbox.ps1',
        _timeout = timeout;

  @override
  Future<List<O365LicenseOption>> listAvailableLicenses({
    required O365SyncSettings settings,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('o365licenses-');
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
      };
      await File(configPath).writeAsString(jsonEncode(config));
      await _restrictPermissions(configPath);

      await _runScript(
        _listLicensesScriptPath,
        configPath,
        outputPath,
        sessionErrorMessage: 'listing available O365 licenses',
      );

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw const O365MailboxException('O365 license lookup produced no results file');
      }

      final decoded = jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;
      final licenses = (decoded['licenses'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      return licenses
          .map((l) => O365LicenseOption(
                skuId: l['skuId'] as String,
                skuPartNumber: l['skuPartNumber'] as String,
                availableUnits: l['availableUnits'] as int,
              ))
          .toList();
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }

  @override
  Future<O365MailboxCreateResult> createMailbox({
    required O365SyncSettings settings,
    required String firstName,
    required String lastName,
    required String localPart,
    required String temporaryPassword,
    required String licenseSkuId,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('o365mailbox-');
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
        'firstName': firstName,
        'lastName': lastName,
        'localPart': localPart,
        'temporaryPassword': temporaryPassword,
        'licenseSkuId': licenseSkuId,
      };
      await File(configPath).writeAsString(jsonEncode(config));
      await _restrictPermissions(configPath);

      await _runScript(
        _createMailboxScriptPath,
        configPath,
        outputPath,
        sessionErrorMessage: 'creating an O365 mailbox',
      );

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw const O365MailboxException('O365 mailbox creation produced no results file');
      }

      final decoded = jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;
      final status = decoded['status'] as String?;
      final upn = decoded['upn'] as String?;
      switch (status) {
        case 'created':
          return O365MailboxCreateResult(upn: upn!, licenseAssigned: true);
        case 'created_license_failed':
          return O365MailboxCreateResult(
            upn: upn!,
            licenseAssigned: false,
            licenseError: decoded['licenseError'] as String? ?? 'Unknown error',
          );
        case 'already_exists':
          throw O365MailboxConflictException(
              'A tenant account already exists at $upn. If this is a retry after an '
              'earlier attempt that failed partway through, that account\'s temporary '
              'password was never saved by Shedbooks — reset it manually in the '
              'Microsoft 365 admin center. If it belongs to someone else, resolve the '
              'naming collision in Entra before retrying.');
        case 'license_unavailable':
          throw const O365MailboxException(
              'The selected license no longer has a spare seat — refresh and pick another.');
        default:
          throw O365MailboxException('Unrecognized create-mailbox result status: $status');
      }
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }

  /// Runs [scriptPath] and returns once it exits successfully; the caller
  /// then reads and parses [outputPath] itself.
  ///
  /// Throws [O365MailboxException] on a whole-session failure (non-zero
  /// exit, timeout, or `pwsh` unavailable) — the caller never sees a
  /// missing-output-file in that case because this always throws first.
  Future<void> _runScript(
    String scriptPath,
    String configPath,
    String outputPath, {
    required String sessionErrorMessage,
  }) async {
    final ProcessResult result;
    try {
      result = await _runProcess('pwsh', [
        '-NoProfile',
        '-NonInteractive',
        '-File', scriptPath,
        '-ConfigPath', configPath,
        '-OutputPath', outputPath,
      ]).timeout(_timeout);
    } on TimeoutException {
      throw O365MailboxException('$sessionErrorMessage timed out after $_timeout');
    } on ProcessException catch (e) {
      throw O365MailboxException(
          'Failed to launch O365 PowerShell session (PowerShell not available?): ${e.message}');
    }

    if (result.exitCode != 0) {
      throw O365MailboxException(
        'O365 session failed while $sessionErrorMessage (exit ${result.exitCode}): '
        '${_snippet(result.stderr.toString())}',
      );
    }
  }

  Future<void> _restrictPermissions(String path) async {
    final result = await _runProcess('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw const O365MailboxException(
          'Failed to restrict permissions on a temporary O365 session file');
    }
  }

  String _snippet(String s) => s.length > 500 ? '${s.substring(0, 500)}...' : s;
}
