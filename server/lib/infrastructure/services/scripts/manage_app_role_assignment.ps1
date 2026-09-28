<#
.SYNOPSIS
  Grants, changes, or revokes a Shedbooks app role (viewer/contributor/
  administrator) for one Entra ID user, via Microsoft Graph.

.DESCRIPTION
  Invoked by GraphAppRoleAssignmentService.setAppRole
  (server/lib/infrastructure/services/graph_app_role_assignment_service.dart),
  itself called from the Membership screen's access-management action and
  the Users screen's role editor.

  Authenticates to Microsoft Graph with the same certificate-based app-only
  credentials as create_o365_mailbox.ps1/list_o365_licenses.ps1 (the
  "Shedbooks O365 Sync" app registration) — reused rather than duplicated,
  so this feature needs no new certificate/credential of its own. That app
  registration must ADDITIONALLY hold the Graph *application* permission
  `AppRoleAssignment.ReadWrite.All` with admin consent — a separate step,
  done in Entra admin center -> App registrations -> (this app) -> API
  permissions -> Add a permission -> Microsoft Graph -> Application
  permissions, exactly like Organization.Read.All/User.ReadWrite.All were
  added for create_o365_mailbox.ps1 (see that script's header). It is not
  Terraform-managed (this app registration isn't in Terraform at all — see
  terraform/entra_login.tf's header) and not granted by this script.

  IMPORTANT — this permission is broad: AppRoleAssignment.ReadWrite.All lets
  the holder assign ANY app role to ANY user for ANY application in the
  tenant, not just Shedbooks Login's three roles. Treat the certificate
  backing this app registration with the same care as a tenant admin
  credential.

  This script is idempotent and self-healing: rather than trusting the
  caller's requested role, it reads back what's actually assigned to
  [ResourceId] after making its change and reports THAT — so
  Shedbooks' local cache (members.shedbooks_app_role) can never drift
  further from Graph reality than one write ever fixes.

  CAUTION — unverified cmdlet surface: `Get-MgUserAppRoleAssignment`,
  `New-MgUserAppRoleAssignment`, and `Remove-MgUserAppRoleAssignment` (all
  Microsoft.Graph.Users) have NOT been confirmed against a live tenant.
  create_o365_mailbox.ps1's header documents a previous real incident where
  a guessed parameter didn't exist and failed silently for months — treat
  this script with the same suspicion until `Get-Command <cmdlet> -Syntax`
  has been run against this tenant and any mismatch fixed.

.PARAMETER ConfigPath
  Path to the JSON input file:
  { tenantId, appId, certificatePath, certificatePassword,
    targetUserId, resourceId, appRole }
  - targetUserId: the target's UPN or Entra object id (Graph accepts either
    for `Get-MgUser -UserId`).
  - resourceId: the Shedbooks Login application's service principal object
    id (terraform/entra_login.tf's `azuread_service_principal.shedbooks_login`,
    surfaced to the server as the ENTRA_LOGIN_SP_OBJECT_ID env var — NOT
    looked up here via Get-MgServicePrincipal, which would need a Graph
    permission and module this app registration doesn't otherwise need).
  - appRole: one of 'viewer'/'contributor'/'administrator', or $null/absent
    to revoke all Shedbooks access.

.PARAMETER OutputPath
  Path to write the JSON results file to: { role }
  `role` is whatever is actually assigned for [ResourceId] after this run
  (one of the three role values, or $null if none) — see file header on
  why this is read back rather than echoing the request.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Role *definition* ids on the Shedbooks Login application itself
# (terraform/entra_login.tf's `app_role` blocks) — fixed for a given
# application registration, not tenant- or user-specific. Safe to hardcode
# here as long as Shedbooks stays a single-application deployment; update
# alongside entra_login.tf if those ids are ever regenerated.
$RoleIds = @{
    viewer        = '46359b54-f197-4e05-a1a6-95813db4992a'
    contributor   = '5e4db24c-a397-4edf-ac80-fba5f00bc6e6'
    administrator = '47c6f44f-1c64-4c17-9518-5fc94028618a'
}

function Write-Result {
    param([string]$Role)
    $payload = [ordered]@{ role = $Role }
    Set-Content -Path $OutputPath -Value ($payload | ConvertTo-Json -Depth 3) -Encoding utf8
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$requestedRole = $config.appRole

if ($requestedRole -and -not $RoleIds.ContainsKey($requestedRole)) {
    [Console]::Error.WriteLine("Unknown app role '$requestedRole' — expected one of: $($RoleIds.Keys -join ', ')")
    exit 1
}

# Everything from here on funnels through ONE catch below, which prints a
# single clean line to stderr via [Console]::Error.WriteLine rather than
# Write-Error. Two reasons: (1) with $ErrorActionPreference = 'Stop',
# Write-Error itself becomes a terminating error — called from inside a
# nested catch, it does not fall through to that catch's own `exit`, it
# gets re-caught by whatever try/catch encloses it, defeating the specific
# message a nested catch is there to add. (2) Write-Error's default
# rendering (a "Write-Error: <path>:<line>" header, a "Line |" source
# excerpt with a tilde underline, then the message) is several lines of
# boilerplate that easily eats the whole snippet budget
# GraphAppRoleAssignmentService truncates stderr to before the actual
# message is reached. `throw "context: $($_.Exception.Message)"` in each
# nested catch below chains cleanly into that single final message instead.
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    # Get-/New-/Remove-MgUserAppRoleAssignment's exact module has not been
    # confirmed against a live tenant (see file header) — Users.Actions is
    # already installed for Set-MgUserLicense (create_o365_mailbox.ps1) and
    # imported defensively here in case the assignment cmdlets live there
    # instead of/as well as Microsoft.Graph.Users.
    Import-Module Microsoft.Graph.Users.Actions -ErrorAction Stop

    $securePassword = ConvertTo-SecureString -String $config.certificatePassword -AsPlainText -Force
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $config.certificatePath, $securePassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)

    try {
        Connect-MgGraph -TenantId $config.tenantId -ClientId $config.appId -Certificate $cert -NoWelcome -ErrorAction Stop
    }
    catch {
        throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    }

    try {
        try {
            $user = Get-MgUser -UserId $config.targetUserId -Property Id -ErrorAction Stop
        }
        catch {
            throw "Could not resolve target user '$($config.targetUserId)': $($_.Exception.Message)"
        }
        $principalId = $user.Id

        try {
            $existing = @(Get-MgUserAppRoleAssignment -UserId $principalId -All -ErrorAction Stop |
                Where-Object { $_.ResourceId -eq $config.resourceId })
        }
        catch {
            throw "Could not read existing app role assignments for '$($config.targetUserId)': $($_.Exception.Message)"
        }

        $desiredRoleId = if ($requestedRole) { $RoleIds[$requestedRole] } else { $null }
        $keptAssignment = $existing | Where-Object { $_.AppRoleId -eq $desiredRoleId } | Select-Object -First 1

        try {
            # Remove every assignment for this resource except one already
            # matching the desired role (if any) — Shedbooks only ever wants
            # at most one active role per user per application.
            foreach ($assignment in $existing) {
                if ($keptAssignment -and $assignment.Id -eq $keptAssignment.Id) { continue }
                Remove-MgUserAppRoleAssignment -UserId $principalId -AppRoleAssignmentId $assignment.Id -ErrorAction Stop
            }

            if ($desiredRoleId -and -not $keptAssignment) {
                New-MgUserAppRoleAssignment -UserId $principalId -PrincipalId $principalId `
                    -ResourceId $config.resourceId -AppRoleId $desiredRoleId -ErrorAction Stop | Out-Null
            }
        }
        catch {
            throw "Could not update the app role assignment for '$($config.targetUserId)': $($_.Exception.Message)"
        }

        try {
            # Read back what's actually in effect now, rather than trusting
            # the requested value — see file header.
            $final = @(Get-MgUserAppRoleAssignment -UserId $principalId -All -ErrorAction Stop |
                Where-Object { $_.ResourceId -eq $config.resourceId })
        }
        catch {
            throw "Could not verify the resulting app role assignment for '$($config.targetUserId)': $($_.Exception.Message)"
        }

        $finalRoleValue = $null
        if ($final.Count -ge 1) {
            $finalRoleId = $final[0].AppRoleId
            $finalRoleValue = ($RoleIds.GetEnumerator() |
                Where-Object { $_.Value -eq $finalRoleId } |
                Select-Object -First 1).Key
        }
        Write-Result -Role $finalRoleValue
    }
    finally {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

exit 0
