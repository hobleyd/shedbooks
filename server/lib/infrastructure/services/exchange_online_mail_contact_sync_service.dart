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

import '../../domain/entities/member.dart';
import '../../domain/entities/o365_sync_settings.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/services/i_o365_contact_sync_service.dart';
import 'process_runner.dart';

/// Pushes members into the tenant's Global Address List as organization-wide
/// mail contacts by invoking `sync_gal_contacts.ps1` under Exchange Online
/// PowerShell (certificate-based app-only auth) — Microsoft Graph has no
/// supported write path for org-wide contacts in a cloud-only tenant.
///
/// Connecting to Exchange Online costs several seconds, so [upsertContacts]
/// always processes a whole batch in one PowerShell invocation/session
/// rather than reconnecting per member.
class ExchangeOnlineMailContactSyncService implements IO365ContactSyncService {
  final ProcessRunner _runProcess;
  final String _scriptPath;
  final Duration _timeout;

  ExchangeOnlineMailContactSyncService({
    ProcessRunner? runProcess,
    String? scriptPath,
    Duration timeout = const Duration(seconds: 90),
  })  : _runProcess = runProcess ?? Process.run,
        _scriptPath = scriptPath ??
            Platform.environment['O365_SYNC_SCRIPT_PATH'] ??
            'scripts/sync_gal_contacts.ps1',
        _timeout = timeout;

  @override
  Future<List<O365ContactSyncResult>> upsertContacts({
    required O365SyncSettings settings,
    required List<Member> members,
  }) async {
    if (members.isEmpty) return const [];

    final tempDir = await Directory.systemTemp.createTemp('o365sync-');
    try {
      final certPath = '${tempDir.path}/cert.pfx';
      final configPath = '${tempDir.path}/config.json';
      final outputPath = '${tempDir.path}/results.json';

      await File(certPath)
          .writeAsBytes(base64Decode(settings.certificatePfxBase64));
      await _restrictPermissions(certPath);

      final config = {
        'tenantId': settings.tenantId,
        'appId': settings.clientId,
        'certificatePath': certPath,
        'certificatePassword': settings.certificatePassword,
        'members': members.map(_memberJson).toList(),
      };
      await File(configPath).writeAsString(jsonEncode(config));
      await _restrictPermissions(configPath);

      final ProcessResult result;
      try {
        // `.timeout` only bounds how long *we* wait — `Process.run` gives no
        // handle to kill the child, so a stalled pwsh keeps running as an
        // orphan until it exits on its own. Accepted tradeoff: the caller
        // (member-save request, or the sync button) must not hang, and the
        // script writes results incrementally (see sync_gal_contacts.ps1),
        // so even an orphaned run's partial progress is recoverable below.
        result = await _runProcess('pwsh', [
          '-NoProfile',
          '-NonInteractive',
          '-File', _scriptPath,
          '-ConfigPath', configPath,
          '-OutputPath', outputPath,
        ]).timeout(_timeout);
      } on TimeoutException {
        final partial = await _tryReadPartialResults(outputPath, members);
        if (partial != null) return partial;
        throw O365ContactSyncException(
            'Exchange Online sync timed out after $_timeout');
      } on ProcessException catch (e) {
        throw O365ContactSyncException(
            'Failed to launch Exchange Online sync (PowerShell not available?): ${e.message}');
      }

      if (result.exitCode != 0) {
        throw O365ContactSyncException(
          'Exchange Online sync failed (exit ${result.exitCode}): '
          '${_snippet(result.stderr.toString())}',
        );
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw const O365ContactSyncException(
            'Exchange Online sync produced no results file');
      }

      return _parseResults(await outputFile.readAsString(), members);
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }

  /// Best-effort recovery after a timeout: the script writes results
  /// incrementally, so a partial file may exist even though we gave up
  /// waiting on the process. Returns null (caller should throw) if there's
  /// nothing usable to read.
  Future<List<O365ContactSyncResult>?> _tryReadPartialResults(
      String outputPath, List<Member> members) async {
    try {
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) return null;
      return _parseResults(await outputFile.readAsString(), members);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _memberJson(Member m) => {
        'memberId': m.id,
        'firstName': m.firstName,
        'lastName': m.lastName,
        'email': m.email,
        'phone': m.phone,
        'streetAddress': m.streetAddress,
        'poBox': m.poBox,
        'membershipStatus': m.membershipStatus,
        'existingContactId': m.o365ContactId,
      };

  /// `chmod 600` — the certificate/config files carry the tenant's private
  /// key and its password, so they must not be group/world-readable even
  /// briefly on disk. (There is a small window between file creation and
  /// this call where default umask permissions apply; acceptable given the
  /// server runs in its own container, not a shared multi-user host.)
  Future<void> _restrictPermissions(String path) async {
    final result = await _runProcess('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw O365ContactSyncException(
          'Failed to restrict permissions on a temporary sync file');
    }
  }

  List<O365ContactSyncResult> _parseResults(
      String raw, List<Member> members) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw O365ContactSyncException(
          'Could not parse Exchange Online sync results: $e');
    }

    final rawResults = decoded['results'];
    // Defensive: guard against a single-member batch serializing `results`
    // as a bare object instead of a one-element array.
    final List<dynamic> resultList = switch (rawResults) {
      List() => rawResults,
      Map() => [rawResults],
      _ => const [],
    };

    final byId = <String, Map<String, dynamic>>{
      for (final r in resultList.cast<Map<String, dynamic>>())
        r['memberId'] as String: r,
    };

    return members.map((m) {
      final r = byId[m.id];
      if (r == null) {
        return O365ContactSyncResult(
          memberId: m.id,
          error:
              const O365ContactSyncException('No result returned for this member'),
        );
      }
      final errorMessage = r['error'] as String?;
      return O365ContactSyncResult(
        memberId: m.id,
        contactId: r['contactId'] as String?,
        error:
            errorMessage != null ? O365ContactSyncException(errorMessage) : null,
      );
    }).toList();
  }

  String _snippet(String s) => s.length > 500 ? '${s.substring(0, 500)}...' : s;
}
