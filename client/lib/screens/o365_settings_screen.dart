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

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import '../auth/auth_state.dart';
import '../models/generated_o365_certificate.dart';
import '../models/o365_sync_settings.dart';
import '../services/api_client.dart';

/// Admin screen for configuring the Microsoft 365 app registration used to
/// sync club members into the tenant's Global Address List as
/// organization-wide mail contacts.
///
/// Uses Exchange Online PowerShell with certificate-based app-only auth —
/// Microsoft Graph has no supported write path for GAL contacts in a
/// cloud-only tenant, so this needs a certificate rather than a client
/// secret, and there is no "target mailbox": GAL contacts aren't scoped to
/// one mailbox.
class O365SettingsScreen extends StatefulWidget {
  const O365SettingsScreen({super.key});

  @override
  State<O365SettingsScreen> createState() => _O365SettingsScreenState();
}

class _O365SettingsScreenState extends State<O365SettingsScreen> {
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  O365SyncSettings? _saved;
  bool _editing = false;

  final _tenantIdController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _certificatePasswordController = TextEditingController();

  Uint8List? _pickedPfxBytes;
  String? _pickedPfxFileName;
  bool _generatingCertificate = false;

  bool get _isCreating => _saved == null;

  @override
  void initState() {
    super.initState();
    _tenantIdController.addListener(_onFieldChanged);
    _clientIdController.addListener(_onFieldChanged);
    _certificatePasswordController.addListener(_onFieldChanged);
    _load();
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _tenantIdController.dispose();
    _clientIdController.dispose();
    _certificatePasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await context.read<ApiClient>().get('/admin/o365-settings');
      if (!mounted) return;

      if (res.statusCode == 404) {
        setState(() {
          _saved = null;
          _editing = true;
          _loading = false;
        });
        return;
      }

      if (res.statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final settings = O365SyncSettings.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      setState(() {
        _saved = settings;
        _editing = false;
        _tenantIdController.text = settings.tenantId;
        _clientIdController.text = settings.clientId;
        _certificatePasswordController.text = '';
        _pickedPfxBytes = null;
        _pickedPfxFileName = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pfx', 'p12'],
      withData: true,
    );
    final bytes = result?.files.first.bytes;
    if (bytes == null) return;
    setState(() {
      _pickedPfxBytes = bytes;
      _pickedPfxFileName = result!.files.first.name;
    });
  }

  /// Asks the server to generate a self-signed certificate. The server
  /// saves it immediately (see `O365SettingsHandler.handleGenerateCertificate`)
  /// and never returns the private key — only the public .cer half, which
  /// this downloads for the admin to upload to Azure. A server-generated
  /// private key has no legitimate reason to round-trip through the
  /// browser, unlike a `.pfx` the admin already has and chooses to upload.
  Future<void> _generateCertificate() async {
    final tenantId = _tenantIdController.text.trim();
    final clientId = _clientIdController.text.trim();
    final password = _certificatePasswordController.text.trim();
    if (tenantId.isEmpty || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter Tenant Domain and Client ID first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a certificate password first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Generating replaces the saved certificate immediately — if the admin
    // never gets around to uploading the new .cer to Azure, sync breaks
    // until they do. Confirm before overwriting a working configuration;
    // no confirmation needed on first-time setup, where nothing works yet.
    if (_saved?.certificateConfigured == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace certificate?'),
          content: const Text(
              'This replaces the saved certificate immediately. Sync will '
              'stop working until you upload the new .cer to Azure — make '
              'sure you complete that step right after generating.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    setState(() => _generatingCertificate = true);
    try {
      final res = await context.read<ApiClient>().post(
          '/admin/o365-settings/generate-certificate',
          jsonEncode({
            'tenantId': tenantId,
            'clientId': clientId,
            'password': password,
          }));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final result = GeneratedO365Certificate.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() {
          _saved = result.settings;
          _editing = false;
          _certificatePasswordController.text = '';
          _pickedPfxBytes = null;
          _pickedPfxFileName = null;
        });
        _downloadBytes(
            base64Decode(result.publicCertBase64), 'shedbooks-o365-cert.cer');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate generated, saved, and downloaded as '
                'shedbooks-o365-cert.cer — upload it to your Azure app '
                'registration.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String msg = 'Certificate generation failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Certificate generation failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingCertificate = false);
    }
  }

  /// Triggers a browser download via a Blob + synthetic anchor click.
  /// Deliberately `package:web`, not `dart:html` — see the note in
  /// transactions_screen.dart's Excel export: the dart:html-era helper
  /// mis-builds the Blob and corrupts binary downloads.
  void _downloadBytes(Uint8List bytes, String filename) {
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = filename
      ..click();
    web.URL.revokeObjectURL(url);
  }

  /// Builds the one-off Exchange Online PowerShell setup script (see the
  /// instructions text in `_buildCertificateRow`) with the admin's own
  /// Tenant Domain / Client ID substituted in, and downloads it. Pure
  /// template substitution of values already visible on this screen — no
  /// server round trip, no secrets involved.
  ///
  /// The Enterprise Application Object ID needed for the
  /// `New-ServicePrincipal` call below is always derived from the Client ID
  /// via Microsoft Graph (`Get-MgServicePrincipal -Filter "appId eq
  /// '...'"`), since Entra ID auto-creates the service principal alongside
  /// the app registration — the admin never needs to look it up by hand.
  void _downloadSetupScript() {
    final tenantId = _tenantIdController.text.trim();
    final clientId = _clientIdController.text.trim();
    if (tenantId.isEmpty || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter Tenant Domain and Client ID first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final objectIdLookup = '''
Write-Host "Looking up the Enterprise Application Object ID for Client ID $clientId..."
\$sp = Get-MgServicePrincipal -Filter "appId eq '$clientId'"
if (-not \$sp) {
    throw "No Enterprise Application (service principal) found in Entra ID for Client ID $clientId. Make sure the app registration exists in this tenant, then re-run this script."
}
\$servicePrincipalObjectId = \$sp.Id
Write-Host "Found Enterprise Application Object ID: \$servicePrincipalObjectId"
''';

    final signInNote = 'NOTE: this script signs you in multiple times, '
        'across two different\nsystems:\n'
        '- Microsoft Graph (once) — to grant this app\'s Entra ID-level '
        'authorizations\n(Exchange.ManageAsApp and the Exchange '
        'Administrator role), and to look\nup the Enterprise Application '
        'Object ID. Safe to run again — everything\nchecks first and skips '
        'what\'s already granted.\n'
        '- Exchange Online (at least twice, a third time only if your '
        'account isn\'t\nyet a member of the Organization Management role '
        'group) — a session\'s RBAC\nrole scope is fixed at connect time, '
        'so anything that changes organization-\nlevel state mid-session '
        'needs a fresh connection to take effect.\n'
        'None of these extra prompts are errors.';

    final script = '''
<#
Shedbooks O365 GAL sync — one-off Exchange Online setup.

Run this once, as a Global Administrator, AFTER uploading
shedbooks-o365-cert.cer to this app registration in the Azure Portal
(App registrations -> (your app) -> Certificates & secrets ->
Certificates -> Upload certificate).

Grants the app registration permission to create and update mail
contacts in your Global Address List. Only needs to be run once per
tenant.

$signInNote
#>

\$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable Microsoft.Graph.Applications)) {
    Install-Module Microsoft.Graph.Applications -Scope CurrentUser -Force
}
if (-not (Get-Module -ListAvailable Microsoft.Graph.Identity.DirectoryManagement)) {
    Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser -Force
}
Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All","RoleManagement.ReadWrite.Directory" -NoWelcome

$objectIdLookup
# Exchange.ManageAsApp lets this app's certificate-based connection to
# Exchange Online PowerShell authenticate at all — separate from the
# "Mail Recipients" role granted further down, which controls what the
# app is allowed to do once connected. Well-known first-party app ID
# below is Microsoft's own "Office 365 Exchange Online" service
# principal, the same in every tenant.
\$exoServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000002-0000-0ff1-ce00-000000000000'"
\$manageAsAppRole = \$exoServicePrincipal.AppRoles | Where-Object { \$_.Value -eq "Exchange.ManageAsApp" }
\$existingGrant = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId \$servicePrincipalObjectId |
    Where-Object { \$_.AppRoleId -eq \$manageAsAppRole.Id -and \$_.ResourceId -eq \$exoServicePrincipal.Id }
if (\$existingGrant) {
    Write-Host "Exchange.ManageAsApp is already granted."
} else {
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId \$servicePrincipalObjectId ``
        -PrincipalId \$servicePrincipalObjectId -ResourceId \$exoServicePrincipal.Id ``
        -AppRoleId \$manageAsAppRole.Id | Out-Null
    Write-Host "Granted Exchange.ManageAsApp with admin consent."
}

# Exchange Administrator directory role — the other half of what lets
# the app connect at all; distinct from Exchange Online's own
# "Mail Recipients" RBAC role granted further down.
\$roleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { \$_.DisplayName -eq "Exchange Administrator" }
\$exchangeAdminRole = Get-MgDirectoryRole -Filter "roleTemplateId eq '\$(\$roleTemplate.Id)'"
if (-not \$exchangeAdminRole) {
    # Built-in roles must be activated in the tenant before members can
    # be added to them — most tenants already have this one active.
    \$exchangeAdminRole = New-MgDirectoryRole -RoleTemplateId \$roleTemplate.Id
}
\$alreadyAssignedRole = Get-MgDirectoryRoleMember -DirectoryRoleId \$exchangeAdminRole.Id |
    Where-Object { \$_.Id -eq \$servicePrincipalObjectId }
if (\$alreadyAssignedRole) {
    Write-Host "Exchange Administrator role is already assigned."
} else {
    New-MgDirectoryRoleMemberByRef -DirectoryRoleId \$exchangeAdminRole.Id -BodyParameter @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/\$servicePrincipalObjectId"
    }
    Write-Host "Assigned the Exchange Administrator role."
}

Disconnect-MgGraph | Out-Null

Connect-ExchangeOnline -Organization "$tenantId" -ShowBanner:\$false

# Required once per tenant before custom role assignments (below) are
# allowed. Safe to run again if already enabled — Exchange just reports it.
try {
    Enable-OrganizationCustomization
} catch {
    Write-Host "Enable-OrganizationCustomization: \$(\$_.Exception.Message)"
}

# The session connected above has its RBAC role scope fixed at connect
# time, so New-ManagementRoleAssignment below can keep refusing even
# though the organization is now genuinely customized. Reconnect to
# pick up the current state — this will prompt you to sign in again.
try {
    Disconnect-ExchangeOnline -Confirm:\$false
} catch {
    Write-Host "Disconnect-ExchangeOnline: \$(\$_.Exception.Message)"
}
Connect-ExchangeOnline -Organization "$tenantId" -ShowBanner:\$false

# New-ManagementRoleAssignment below requires your account to hold Role
# Management rights, which by default only Organization Management (or
# a role explicitly granted Role Management) has — Global Administrator
# in Entra ID alone isn't always enough if it hasn't synced through.
# Existence-probe rather than parsing Add-RoleGroupMember's error text,
# since that text is locale/version-fragile.
\$currentUser = (Get-ConnectionInformation | Select-Object -First 1 -ExpandProperty UserPrincipalName)
\$alreadyInOrgMgmt = [bool](Get-RoleGroupMember -Identity "Organization Management" |
    Where-Object { \$_.PrimarySmtpAddress -eq \$currentUser -or \$_.Name -eq \$currentUser })
if (\$alreadyInOrgMgmt) {
    Write-Host "\$currentUser is already a member of Organization Management."
} else {
    try {
        Add-RoleGroupMember -Identity "Organization Management" -Member \$currentUser
        Write-Host "Added \$currentUser to Organization Management — reconnecting so the new role takes effect."
        try {
            Disconnect-ExchangeOnline -Confirm:\$false
        } catch {
            Write-Host "Disconnect-ExchangeOnline: \$(\$_.Exception.Message)"
        }
        Connect-ExchangeOnline -Organization "$tenantId" -ShowBanner:\$false
    } catch {
        Write-Host "Could not add \$currentUser to Organization Management automatically: \$(\$_.Exception.Message)"
        Write-Host "Add yourself manually: https://admin.exchange.microsoft.com -> Roles -> Admin roles -> Organization Management -> Edit -> add your account, then re-run this script."
    }
}

# Idempotent: skip creation if this app already has a service principal
# registered in Exchange Online — e.g. a previous run of this script
# already succeeded here but failed on the role assignment below.
\$existingSp = Get-ServicePrincipal | Where-Object { \$_.AppId -eq "$clientId" }
if (\$existingSp) {
    Write-Host "Service principal already registered in Exchange Online — skipping New-ServicePrincipal."
} else {
    New-ServicePrincipal -AppId "$clientId" -ObjectId \$servicePrincipalObjectId -DisplayName "Shedbooks O365 Sync"
}

# Small safety net for genuine replication lag — the reconnect above is
# the real fix for the "already enabled but still refused" loop.
\$maxAttempts = 2
\$delaySeconds = 15
for (\$attempt = 1; \$attempt -le \$maxAttempts; \$attempt++) {
    try {
        New-ManagementRoleAssignment -Role "Mail Recipients" -App "$clientId"
        break
    } catch {
        \$isCustomizationLag = \$_.Exception.Message -like "*Enable-OrganizationCustomization*"
        if (\$isCustomizationLag -and \$attempt -lt \$maxAttempts) {
            Write-Host "Role assignment not ready yet — retrying in \$delaySeconds s (attempt \$attempt of \$maxAttempts)..."
            Start-Sleep -Seconds \$delaySeconds
        } elseif (\$isCustomizationLag) {
            throw "Still refused after reconnecting and confirming Organization Management membership. This may be a longer-than-usual replication delay — wait a while and re-run this script (it's safe to run again)."
        } else {
            throw
        }
    }
}

Write-Host "Setup complete. $clientId can now create and update GAL mail contacts."
''';

    _downloadBytes(
        Uint8List.fromList(utf8.encode(script)), 'shedbooks-o365-setup.ps1');
  }

  String _isoDate(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = jsonEncode({
        'tenantId': _tenantIdController.text.trim(),
        'clientId': _clientIdController.text.trim(),
        if (_pickedPfxBytes != null)
          'certificatePfxBase64': base64Encode(_pickedPfxBytes!),
        'certificatePassword': _certificatePasswordController.text.trim(),
      });

      final res =
          await context.read<ApiClient>().put('/admin/o365-settings', body);
      if (!mounted) return;

      if (res.statusCode == 200) {
        final settings = O365SyncSettings.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() {
          _saved = settings;
          _editing = false;
          _saving = false;
          _certificatePasswordController.text = '';
          _pickedPfxBytes = null;
          _pickedPfxFileName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O365 sync settings saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String msg = 'Save failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _startEdit() {
    setState(() {
      _tenantIdController.text = _saved!.tenantId;
      _clientIdController.text = _saved!.clientId;
      _certificatePasswordController.text = '';
      _pickedPfxBytes = null;
      _pickedPfxFileName = null;
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _tenantIdController.text = _saved!.tenantId;
      _clientIdController.text = _saved!.clientId;
      _certificatePasswordController.text = '';
      _pickedPfxBytes = null;
      _pickedPfxFileName = null;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            _buildError()
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isAdmin = context.watch<AuthState>().isAdmin;
    return Row(
      children: [
        Text('O365 Sync', style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        if (!_loading && _loadError == null) ...[
          if (isAdmin && !_editing && !_isCreating)
            FilledButton.icon(
              onPressed: _startEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          if (isAdmin && _editing && !_isCreating) ...[
            OutlinedButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update'),
            ),
          ],
          if (isAdmin && _isCreating)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
            ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isCreating)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'O365 sync has not been configured yet. Register an Azure AD '
                'application (Microsoft Entra ID → App registrations → New '
                'registration), then enter its details below — each field '
                'explains where to find the value on the right. You will '
                'also need to run a one-off Exchange Online PowerShell setup '
                'step as a tenant admin (see the Certificate instructions '
                'below) before syncing will work.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else ...[
            _buildStatusBanner(),
            const SizedBox(height: 20),
          ],
          _buildFieldRow(
            label: 'Tenant Domain',
            controller: _tenantIdController,
            isRequired: true,
            instructions:
                'Your tenant\'s default domain, e.g. yourclub.onmicrosoft.com '
                '— Azure Portal → Microsoft Entra ID → Overview → "Primary '
                'domain" (or Custom domain names, if you use one). Do NOT '
                'use the "Tenant ID" / "Directory ID" GUID shown on the same '
                'page — the certificate-based connection Shedbooks uses for '
                'automatic syncing requires the domain, not the GUID.',
          ),
          const SizedBox(height: 20),
          _buildFieldRow(
            label: 'Client ID',
            controller: _clientIdController,
            isRequired: true,
            instructions:
                'Azure Portal → Microsoft Entra ID → App registrations → '
                '(your app) → Overview. Copy the "Application (client) ID".',
          ),
          const SizedBox(height: 20),
          _buildFieldRow(
            label: 'Certificate Password',
            controller: _certificatePasswordController,
            isRequired: _isCreating,
            obscureText: true,
            instructions:
                'Choose a password to protect the certificate Shedbooks '
                'generates below. It\'s stored encrypted here, but keep a '
                'copy yourself too — you\'ll need it if you ever re-import '
                'this certificate elsewhere or troubleshoot the Exchange '
                'Online connection by hand.',
          ),
          const SizedBox(height: 20),
          _buildCertificateRow(),
        ],
      ),
    );
  }

  /// A form field paired with instructions on where to find its value,
  /// laid out side by side so the "how do I get this" context is always
  /// visible next to the field it applies to.
  Widget _buildFieldRow({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    bool obscureText = false,
    String? instructions,
    TextInputType? keyboardType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: _buildField(
            label: label,
            controller: controller,
            enabled: _editing,
            isRequired: isRequired,
            obscureText: obscureText,
            keyboardType: keyboardType,
          ),
        ),
        if (instructions != null) ...[
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              instructions,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCertificateRow() {
    final hasExisting = _saved?.certificateConfigured == true;
    final missing = _editing && _isCreating && _pickedPfxBytes == null;
    final canAct = _editing && !_saving && !_generatingCertificate;
    String statusText;
    if (_pickedPfxFileName != null) {
      statusText = _pickedPfxFileName!;
    } else if (hasExisting) {
      statusText = 'A certificate is already saved — generate or choose a '
          'file only to replace it.';
    } else {
      statusText = 'No certificate yet';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                missing ? 'Certificate (!)' : 'Certificate',
                style: TextStyle(
                  fontSize: 12,
                  color: missing ? Colors.red : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: canAct ? _generateCertificate : null,
                icon: _generatingCertificate
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.key_outlined, size: 18),
                label: Text(_generatingCertificate
                    ? 'Generating…'
                    : 'Generate Certificate'),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: canAct ? _pickCertificate : null,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('or choose an existing .pfx file'),
              ),
              const SizedBox(height: 4),
              Text(
                statusText,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Tenant Domain, Client ID and a Certificate Password '
                'above, then click "Generate Certificate" — Shedbooks '
                'creates the certificate, saves these settings, and '
                'downloads the public key as shedbooks-o365-cert.cer.\n'
                '1. Upload that .cer to Azure Portal → App registrations '
                '→ your app → Certificates & secrets → Certificates → '
                'Upload certificate.\n'
                '2. Download the setup script below and, as a Global '
                'Administrator, run it (cannot be done from the Azure '
                'Portal UI) — it grants this app permission to create '
                'and update GAL mail contacts, looking up its Enterprise '
                'Application Object ID itself.\n'
                '3. Azure Portal → App registrations → your app → API '
                'permissions → Add a permission → APIs my organization '
                'uses → Office 365 Exchange Online → Application '
                'permissions → Exchange.ManageAsApp → Add, then click '
                '"Grant admin consent" (adding it alone isn\'t enough — '
                'it must show as Granted).\n'
                '4. Microsoft Entra ID → Roles and administrators → '
                'Exchange Administrator → Add assignments → search for '
                'this app by name → Assign. This is separate from step 2 '
                '— step 2 lets the app manage mail contacts once '
                'connected, this lets it connect at all. Without both, '
                'syncing fails with "UnAuthorized".',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _downloadSetupScript,
                icon: const Icon(Icons.terminal_outlined, size: 16),
                label: const Text(
                    'Download setup script (shedbooks-o365-setup.ps1)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final enabled = _saved?.autoSyncEnabled ?? false;
    final expiresAt = _saved?.certificateExpiresAt;
    final expiringSoon = expiresAt != null &&
        expiresAt
            .isBefore(DateTime.now().toUtc().add(const Duration(days: 30)));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: enabled ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: enabled ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled
                      ? 'Auto-sync is on — new and edited members are pushed to the GAL automatically.'
                      : 'Auto-sync is off until you run "Sync to O365" from the Members page at least once.',
                  style: TextStyle(
                    fontSize: 13,
                    color: enabled
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                if (expiresAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      expiringSoon
                          ? 'Certificate expires ${_isoDate(expiresAt)} — regenerate it soon to avoid sync failures.'
                          : 'Certificate expires ${_isoDate(expiresAt)}.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            expiringSoon ? Colors.red.shade700 : Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool isRequired = false,
    bool obscureText = false,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    final isEmpty = isRequired && controller.text.trim().isEmpty;
    return TextFormField(
      controller: controller,
      enabled: enabled && !_saving && !_generatingCertificate,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: isEmpty ? '$label (!)' : label,
        labelStyle: isEmpty ? const TextStyle(color: Colors.red) : null,
        helperText: helperText,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade50,
      ),
    );
  }
}
