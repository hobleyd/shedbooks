<#
.SYNOPSIS
  Creates a tenant sign-in account (Entra ID user + Exchange mailbox) for a
  club member and assigns it a Microsoft 365 license.

.DESCRIPTION
  Invoked by ExchangeOnlineMailboxService.createMailbox
  (server/lib/infrastructure/services/exchange_online_mailbox_service.dart),
  itself called from the "Create O365 mailbox" admin action on the members
  screen. Unlike sync_gal_contacts.ps1 (which only ever creates mail
  *contacts* — no sign-in, no mailbox), this creates a real account someone
  can log into.

  Two authenticated sessions are used — Microsoft Graph and Exchange
  Online are unrelated systems with no shared transaction, so a mailbox
  can't be created through Graph alone. The Graph session is held open
  across both the pre-check and the post-creation license assignment
  (rather than reconnecting a third time) purely to save the several
  seconds a fresh `Connect-MgGraph` costs — see the timeout budget in
  ExchangeOnlineMailboxService and client/nginx.conf.template's
  `proxy_read_timeout` for this endpoint, both sized against this script's
  actual connect count:
   1. Connect-MgGraph — re-verify the chosen license SKU still has a spare
      seat (never trust the caller's earlier list call; a seat may have
      been taken by a concurrent request since).
   2. Connect-ExchangeOnline — check the target address isn't already in
      use, then New-Mailbox with the generated password and a forced
      change on next sign-in. Disconnected once done.
   3. Using the still-open Graph session: set UsageLocation (Entra refuses
      a license assignment without one) and assign the license. Run as a
      distinct step from #1, not merged into one Graph call, because
      Exchange mailbox creation (#2) sits in between and this step must
      still run — and still report success/failure independently of
      whether the mailbox was created — regardless of what #1 found:
      if this fails, the account and mailbox from #2 already exist and
      are NOT rolled back (undoing a freshly created mailbox has its own
      failure modes, e.g. a directory-replication race, that would only
      compound the problem) — instead this is reported as
      `created_license_failed` so Dart still records the member as having
      a mailbox (it does) while surfacing the license failure for the
      admin to resolve manually.

  Requires the app registration to hold:
   - Microsoft Graph *application* permissions `Organization.Read.All` and
     `User.ReadWrite.All`, with admin consent.
   - The Exchange RBAC "Mail Recipient Creation" role (New-Mailbox is not
     covered by "Mail Recipients", which only permits update/read of
     already-existing recipients) — see setup_exchange_rbac.ps1.
  Both are separate grants from each other and from whatever was already
  configured for sync_gal_contacts.ps1's contact-sync feature.

  CAUTION — unverified cmdlet surface: `New-Mailbox`'s parameter set,
  `Set-MgUserLicense -AddLicenses`'s expected shape (an array of
  hashtables, not a bare hashtable — Graph's assignLicense payload is a
  list), `Get-MgSubscribedSku -SubscribedSkuId`, and
  `Connect-MgGraph -Certificate` have NOT been confirmed against a live
  tenant. sync_gal_contacts.ps1's header documents a previous real
  incident where a guessed parameter (`Set-Contact -CustomAttribute1`)
  didn't exist and failed silently for months — treat this script with
  the same suspicion until `Get-Command <cmdlet> -Syntax` has been run
  against this tenant and any mismatch fixed.

.PARAMETER ConfigPath
  Path to the JSON input file:
  { tenantId, appId, certificatePath, certificatePassword,
    firstName, lastName, localPart, temporaryPassword, licenseSkuId }

.PARAMETER OutputPath
  Path to write the JSON results file to:
  { status, upn, licenseError }
  `status` is one of:
   - "created"                — mailbox created and licensed.
   - "created_license_failed" — mailbox created; `licenseError` explains why
                                 licensing failed. The account/password are
                                 still valid.
   - "already_exists"         — `upn` was already taken; nothing was created.
                                 If this is a retry after a prior
                                 `created_license_failed`/timeout, the
                                 member's temporary password from that
                                 earlier run is lost — Shedbooks never
                                 persists it — and must be reset manually
                                 in the Microsoft 365 admin center.
   - "license_unavailable"    — the requested SKU no longer has a spare
                                 seat; nothing was created.
  The temporary password is deliberately NOT included here — the Dart
  caller already holds it (it generated it) and it must never be written
  to a file on disk. A missing OutputPath means the whole session failed
  before any of the above could be determined (bad certificate, module
  missing, network failure).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Hardcoded rather than a per-entity setting: every Shedbooks deployment to
# date is an Australian club (ABN lookup, GST handling elsewhere in this
# codebase assume AU). If a non-AU tenant ever needs this feature, add a
# `usageLocation` field to O365SyncSettings instead of guessing here.
$UsageLocation = 'AU'

function Write-Result {
    param([string]$Status, [string]$Upn = $null, [string]$LicenseError = $null)
    $payload = [ordered]@{ status = $Status; upn = $Upn; licenseError = $LicenseError }
    $json = $payload | ConvertTo-Json -Depth 4
    Set-Content -Path $OutputPath -Value $json -Encoding utf8
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$upn = "$($config.localPart)@$($config.tenantId)"

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Users.Actions -ErrorAction Stop
Import-Module ExchangeOnlineManagement -ErrorAction Stop

$securePassword = ConvertTo-SecureString -String $config.certificatePassword -AsPlainText -Force
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
    $config.certificatePath, $securePassword,
    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)

# ── Step 1: connect to Graph, re-verify the chosen license has a spare seat ─
# Held open through Step 3 — see file header for why.
try {
    Connect-MgGraph -TenantId $config.tenantId -ClientId $config.appId -Certificate $cert -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

try {
    try {
        # -SubscribedSkuId (a "get by id" call) expects Graph's compound
        # `id` property (documented as `{accountId}_{skuId}`), NOT the bare
        # SKU GUID list_o365_licenses.ps1 exposes as `SkuId` and that Dart
        # echoes back here as licenseSkuId — passing the bare GUID into
        # that parameter fails with a Graph "Request_BadRequest" error.
        # Filtering the full list by `SkuId` avoids the id-vs-skuId
        # confusion entirely and matches how the license was surfaced to
        # the admin in the first place.
        $sku = Get-MgSubscribedSku -All -ErrorAction Stop | Where-Object { $_.SkuId -eq $config.licenseSkuId }
        if (-not $sku) {
            throw "No license SKU found in this tenant matching SkuId $($config.licenseSkuId)."
        }
        $available = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
        if ($available -le 0) {
            Write-Result -Status 'license_unavailable' -Upn $upn
            exit 0
        }
    }
    catch {
        Write-Error "Failed to look up the requested license SKU: $($_.Exception.Message)"
        exit 1
    }

    # ── Step 2: create the mailbox (Exchange Online) ────────────────────────
    try {
        Connect-ExchangeOnline `
            -AppId $config.appId `
            -CertificateFilePath $config.certificatePath `
            -CertificatePassword $securePassword `
            -Organization $config.tenantId `
            -ShowBanner:$false `
            -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
        exit 1
    }

    try {
        $existing = Get-User -Identity $upn -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Result -Status 'already_exists' -Upn $upn
            exit 0
        }

        $displayName = ("$($config.firstName) $($config.lastName)").Trim()
        if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = $upn }

        $mailboxPassword = ConvertTo-SecureString -String $config.temporaryPassword -AsPlainText -Force
        New-Mailbox -Name $displayName -MicrosoftOnlineServicesID $upn `
            -Password $mailboxPassword -ResetPasswordOnNextLogon $true `
            -FirstName $config.firstName -LastName $config.lastName `
            -DisplayName $displayName -Alias $config.localPart `
            -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to create mailbox: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }

    # ── Step 3: license the new user (still on the Step 1 Graph session) ────
    # The mailbox above already exists regardless of what happens from here —
    # every path below must exit 0 and write a result rather than throw, so
    # Dart still records the member as having a mailbox (see file header).
    try {
        # Entra rejects a license assignment with no UsageLocation set —
        # New-Mailbox does not populate it.
        Update-MgUser -UserId $upn -UsageLocation $UsageLocation -ErrorAction Stop
        # -AddLicenses expects an array of assigned-license objects, not a
        # bare hashtable — Graph's underlying assignLicense payload is a list.
        Set-MgUserLicense -UserId $upn `
            -AddLicenses @(@{ SkuId = $config.licenseSkuId }) -RemoveLicenses @() `
            -ErrorAction Stop | Out-Null
        Write-Result -Status 'created' -Upn $upn
    }
    catch {
        Write-Result -Status 'created_license_failed' -Upn $upn -LicenseError $_.Exception.Message
    }
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

exit 0
