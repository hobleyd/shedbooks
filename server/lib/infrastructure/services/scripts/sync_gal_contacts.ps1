<#
.SYNOPSIS
  Syncs Shedbooks club members into the tenant's Global Address List as
  organization-wide mail contacts, via Exchange Online PowerShell app-only
  (certificate-based) authentication.

.DESCRIPTION
  Invoked once per sync batch by ExchangeOnlineMailContactSyncService
  (server/lib/infrastructure/services/exchange_online_mail_contact_sync_service.dart).
  Reads a JSON config describing the tenant/app/certificate and the members
  to sync, connects to Exchange Online once, creates or updates one mail
  contact per member, and writes a JSON results file.

  Existing contacts are matched by the id Shedbooks already recorded for
  that member (member.existingContactId — the created contact's `.Identity`
  from a previous sync; NOT `ExternalDirectoryObjectId`, which is populated
  asynchronously by directory sync and may not be available immediately
  after New-MailContact returns). Its existence is probed with
  Get-MailContact before use; if it no longer resolves (the contact was
  deleted directly in the GAL), a new contact is created in its place
  rather than failing the member.

  A member with no email address cannot have a mail contact created for it
  (ExternalEmailAddress is required by Exchange) and is reported as a
  per-member error rather than silently skipped.

  Every field is re-applied on every sync — Shedbooks is treated as the
  source of truth, so a field cleared in Shedbooks is cleared in the GAL
  contact too.

  Results are written to OutputPath after EVERY member, not just at the
  end — if the batch is interrupted partway (session dropped, throttling,
  an unexpected error outside the per-member try/catch), members already
  created in Exchange are still recorded. Without this, an interrupted run
  would lose those ids and the next run would create duplicate contacts for
  them. A missing OutputPath still means "the session itself never
  connected" — see the Connect-ExchangeOnline catch block below, which is
  the only path that exits without ever calling Write-PartialResults.

.PARAMETER ConfigPath
  Path to the JSON input file:
  { tenantId, appId, certificatePath, certificatePassword,
    members: [ { memberId, firstName, lastName, email, phone,
                 streetAddress, poBox, membershipStatus, existingContactId } ] }

.PARAMETER OutputPath
  Path to write the JSON results file to:
  { results: [ { memberId, contactId, error }, ... ] }
  Only written after a successful connection to Exchange Online — its
  absence tells the caller the whole session failed before any member was
  attempted (bad certificate, module missing, network failure, etc), as
  distinct from an individual member's error.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Overwrites OutputPath with everything accumulated so far. Called after
# every member (not just at the end) so an interrupted batch still leaves a
# usable, if partial, results file — see the file-level comment above.
function Write-PartialResults {
    param([array]$Results)
    # Force array serialization even for zero/one-element batches — a bare
    # object would break the Dart side's `results` list parsing.
    $payload = [ordered]@{ results = @($Results) }
    $json = $payload | ConvertTo-Json -Depth 6
    Set-Content -Path $OutputPath -Value $json -Encoding utf8
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

Import-Module ExchangeOnlineManagement -ErrorAction Stop

$securePassword = ConvertTo-SecureString -String $config.certificatePassword -AsPlainText -Force

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
    # Deliberately no results file — this is a whole-session failure, not a
    # per-member one, so the caller must not interpret an empty/missing
    # file as "zero members needed syncing".
    Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
    exit 1
}

$results = @()

try {
    foreach ($member in $config.members) {
        $result = [ordered]@{ memberId = $member.memberId; contactId = $null; error = $null }
        try {
            if ([string]::IsNullOrWhiteSpace($member.email)) {
                throw 'Member has no email address — a GAL mail contact requires one.'
            }

            $displayName = ("$($member.firstName) $($member.lastName)").Trim()
            if ([string]::IsNullOrWhiteSpace($displayName)) { $displayName = $member.email }

            # Name (distinct from DisplayName) must be unique across the org's
            # recipients; suffixing with the member id avoids collisions
            # between same-named members without affecting what's shown in
            # Outlook/the GAL (that's DisplayName).
            $shortId = $member.memberId.Substring(0, [Math]::Min(8, $member.memberId.Length))
            $internalName = "$displayName (SB-$shortId)"

            $notesLines = @()
            if ($member.membershipStatus) { $notesLines += "Membership status: $($member.membershipStatus)" }
            $notes = $notesLines -join "`n"

            $streetParts = @($member.streetAddress, $member.poBox) | Where-Object { $_ }
            $street = $streetParts -join ', '

            # CustomAttribute1 carries the Shedbooks member id as a
            # breadcrumb for admins inspecting the GAL entry directly — the
            # actual lookup key Shedbooks uses is existingContactId, not this.
            $contactParams = @{
                Notes            = $notes
                CustomAttribute1 = $member.memberId
            }
            if ($member.phone) { $contactParams['Phone'] = $member.phone }
            if ($street) { $contactParams['StreetAddress'] = $street }

            $identity = $null
            if ($member.existingContactId) {
                # Probe existence rather than matching Set-*'s error text —
                # error message wording is locale- and version-fragile.
                $existing = Get-MailContact -Identity $member.existingContactId -ErrorAction SilentlyContinue
                if ($existing) {
                    Set-MailContact -Identity $member.existingContactId `
                        -Name $internalName -DisplayName $displayName `
                        -ExternalEmailAddress $member.email -ErrorAction Stop | Out-Null
                    Set-Contact -Identity $member.existingContactId @contactParams -ErrorAction Stop | Out-Null
                    $identity = $member.existingContactId
                }
                # else: stale id — contact was deleted directly in the GAL. Fall through to recreate.
            }

            if (-not $identity) {
                $created = New-MailContact -Name $internalName -DisplayName $displayName `
                    -ExternalEmailAddress $member.email -ErrorAction Stop
                Set-Contact -Identity $created.Identity @contactParams -ErrorAction Stop | Out-Null
                # .Identity (not ExternalDirectoryObjectId) — see file-level comment.
                $identity = $created.Identity.ToString()
            }

            $result.contactId = $identity
        }
        catch {
            $result.error = $_.Exception.Message
        }
        $results += [pscustomobject]$result
        Write-PartialResults -Results $results
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

exit 0
