<#
.SYNOPSIS
  One-time-per-tenant setup: grants the Shedbooks O365 sync app
  registration the Exchange Online RBAC roles it needs to run
  sync_gal_contacts.ps1 — both the original mail-contact sync and the
  "Shed Members" distribution-list management added later.

.DESCRIPTION
  Run this once, interactively, as an Exchange admin, against any new
  tenant that will use Shedbooks' O365 GAL sync feature. It is safe to
  re-run — every step checks current state before changing anything.

  Background: Connect-ExchangeOnline in sync_gal_contacts.ps1 uses
  certificate-based app-only auth (-AppId/-CertificateFilePath, no
  interactive user). Exchange Online authorizes an app-only session
  purely by RBAC role assignments made to that app's Exchange-side
  ServicePrincipal object — Azure AD API permissions/admin consent alone
  are NOT enough; without an Exchange RBAC role assignment, every cmdlet
  the script calls fails with an authorization error regardless of what
  the Azure AD app registration itself allows.

  Confirmed against a live tenant on 2026-08-22: an app already granted
  "Mail Recipients" (letting mail-contact sync work fine) had no
  "Distribution Groups" assignment, so New-/Set-DistributionGroup and
  Update-DistributionGroupMember all failed — invisibly, because
  sync_gal_contacts.ps1 deliberately treats distribution-list failures
  as non-fatal warnings (a DL failure must not discard the per-member
  contact results already written that run). This script exists so that
  gap is caught and fixed once, up front, instead of per-tenant trial and
  error.

  Two roles are ensured:
    - "Mail Recipients"    — New-/Set-MailContact, Set-Contact (member sync)
    - "Distribution Groups" — New-/Set-DistributionGroup,
                               Update-DistributionGroupMember, Get-DistributionGroup
                               ("Shed Members" list management)

.PARAMETER AppId
  The Azure AD Application (client) ID of the Shedbooks O365 sync app
  registration — matches O365SyncSettings.clientId in the Shedbooks
  database, and the "appId" written into config.json by
  ExchangeOnlineMailContactSyncService.

.PARAMETER ServicePrincipalObjectId
  The Azure AD **Enterprise Application** Object ID for this app (found
  in Entra admin center → Enterprise applications → search by AppId →
  Object ID — NOT the App registration's own Object ID, a different
  value). Only required the FIRST time this runs for a given tenant, if
  Exchange has no ServicePrincipal object for this AppId yet. Omit on
  subsequent runs; the script finds the existing one automatically.

.PARAMETER DisplayName
  Friendly name for the ServicePrincipal if it needs to be created.
  Defaults to "Shedbooks O365 Sync".

.EXAMPLE
  ./setup_exchange_rbac.ps1 -AppId 192514fa-341d-445d-b147-26c45f0af99c `
      -ServicePrincipalObjectId 3fa1e6b2-....

.EXAMPLE
  # Re-run later (e.g. to pick up a newly added role requirement) without
  # needing the Object ID again:
  ./setup_exchange_rbac.ps1 -AppId 192514fa-341d-445d-b147-26c45f0af99c
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [string]$ServicePrincipalObjectId,

    [string]$DisplayName = 'Shedbooks O365 Sync'
)

$ErrorActionPreference = 'Stop'

# Every RBAC role this feature needs, and the reason for each — extend
# this list (and re-run) if a future feature needs another cmdlet's role.
$requiredRoles = @(
    @{ Role = 'Mail Recipients'; Reason = 'member GAL contact sync (New-/Set-MailContact, Set-Contact)' }
    @{ Role = 'Distribution Groups'; Reason = '"Shed Members" distribution list (New-/Set-DistributionGroup, Update-DistributionGroupMember)' }
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

Write-Host "Connecting to Exchange Online — a browser/MFA prompt will appear (use an Exchange admin account)..." -ForegroundColor Cyan
Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

try {
    Write-Host "`n--- Step 1: Exchange-side ServicePrincipal for AppId $AppId ---" -ForegroundColor Cyan
    $sp = @(Get-ServicePrincipal -ErrorAction Stop | Where-Object { $_.AppId -eq $AppId })
    if ($sp.Count -gt 1) {
        throw "Multiple ServicePrincipal objects found for AppId $AppId — resolve this duplication manually before continuing (Get-ServicePrincipal | Where-Object { `$_.AppId -eq '$AppId' })."
    }

    if ($sp.Count -eq 1) {
        $sp = $sp[0]
        Write-Host "Found existing ServicePrincipal: $($sp.DisplayName) (ObjectId $($sp.ObjectId))" -ForegroundColor Green
    } else {
        if (-not $ServicePrincipalObjectId) {
            throw "No ServicePrincipal exists for AppId $AppId yet, and -ServicePrincipalObjectId was not supplied. " +
                  "Find it in Entra admin center -> Enterprise applications -> search '$AppId' -> Object ID, then re-run with -ServicePrincipalObjectId."
        }
        Write-Host "No existing ServicePrincipal — creating one (DisplayName '$DisplayName')..."
        $sp = New-ServicePrincipal -AppId $AppId -ObjectId $ServicePrincipalObjectId -DisplayName $DisplayName -ErrorAction Stop
        Write-Host "Created ServicePrincipal: $($sp.DisplayName) (ObjectId $($sp.ObjectId))" -ForegroundColor Green
    }

    Write-Host "`n--- Step 2: current role assignments ---" -ForegroundColor Cyan
    $existingAssignments = @(Get-ManagementRoleAssignment -RoleAssignee $sp.DisplayName -ErrorAction SilentlyContinue)
    if ($existingAssignments.Count -eq 0) {
        # DisplayName lookup can occasionally fail to resolve as a RoleAssignee
        # identity depending on tenant/module version; ObjectId is the fallback.
        $existingAssignments = @(Get-ManagementRoleAssignment -RoleAssignee $sp.ObjectId.ToString() -ErrorAction SilentlyContinue)
    }
    $existingRoleNames = @($existingAssignments | Select-Object -ExpandProperty Role -Unique)
    if ($existingRoleNames.Count -gt 0) {
        Write-Host ("Currently assigned: " + ($existingRoleNames -join ', '))
    } else {
        Write-Host "No roles currently assigned."
    }

    Write-Host "`n--- Step 3: granting missing roles ---" -ForegroundColor Cyan
    foreach ($entry in $requiredRoles) {
        $role = $entry.Role
        if ($role -in $existingRoleNames) {
            Write-Host "'$role' already assigned — skipping ($($entry.Reason))." -ForegroundColor Green
            continue
        }

        Write-Host "Granting '$role' ($($entry.Reason))..."
        # -App is the confirmed write form for this module/tenant version
        # (New-ManagementRoleAssignment): verified 2026-08-22 that -App
        # exists and succeeds, while -RoleAssignee/-RoleAssigneeType does
        # NOT exist as a parameter on New- here at all — the exact reverse
        # of Get-ManagementRoleAssignment, which supports -RoleAssignee but
        # not -App (that asymmetry is why Step 2/4 below read via
        # -RoleAssignee while this step writes via -App; they are not
        # interchangeable on this module version, do not "simplify" this
        # to one form without re-confirming both directions first).
        New-ManagementRoleAssignment -Role $role -App $AppId -ErrorAction Stop | Out-Null
        Write-Host "  Granted." -ForegroundColor Green
    }

    Write-Host "`n--- Step 4: verification ---" -ForegroundColor Cyan
    Write-Host "(A grant that just succeeded above with -ErrorAction Stop is real — if the check below still shows it missing, that's directory replication lag, not a failed grant; re-run this script in a few minutes rather than assuming it didn't work.)"
    $finalAssignments = @(Get-ManagementRoleAssignment -RoleAssignee $sp.DisplayName -ErrorAction SilentlyContinue)
    if ($finalAssignments.Count -eq 0) {
        $finalAssignments = @(Get-ManagementRoleAssignment -RoleAssignee $sp.ObjectId.ToString() -ErrorAction SilentlyContinue)
    }
    $finalRoleNames = @($finalAssignments | Select-Object -ExpandProperty Role -Unique)
    $missing = @($requiredRoles | ForEach-Object { $_.Role } | Where-Object { $_ -notin $finalRoleNames })

    if ($missing.Count -eq 0) {
        Write-Host "All required roles are assigned: $($finalRoleNames -join ', ')" -ForegroundColor Green
        Write-Host "This tenant is ready for Shedbooks O365 GAL contact + distribution list sync."
        Write-Host "Note: app-only sessions can take several minutes to pick up a new role grant — an immediate sync run may still fail even though this succeeded." -ForegroundColor Yellow
    } else {
        Write-Warning "Still showing as missing: $($missing -join ', '). If the grant above reported success, this is most likely replication lag — re-run this script in a few minutes before assuming the grant failed."
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
