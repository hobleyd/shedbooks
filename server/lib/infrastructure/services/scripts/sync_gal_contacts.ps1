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
  that member (member.existingContactId — an email address or a `.Identity`
  string from a previous sync; NOT `ExternalDirectoryObjectId`, which is
  populated asynchronously by directory sync and may not be available
  immediately after New-MailContact returns). Its existence is probed with
  Get-MailContact before use; if it no longer resolves (the contact was
  deleted directly in the GAL), the script falls back to an orphan lookup
  (below) rather than assuming none exists.

  When there is no existingContactId (first sync, or a stale one), the
  script does NOT immediately create a new contact — it first looks up
  Get-MailContact by EMAIL address (`Get-MailContact -Filter
  "EmailAddresses -eq 'smtp:<address>'"`, confirmed against the live
  tenant) to check for a contact already using it, from an earlier run
  (this environment's or another Shedbooks environment's — see below) that
  created it in Exchange but never recorded the id. Matched by email, NOT
  by Name: Name embeds the id of whichever Shedbooks member record most
  recently synced this person (`$internalName` below, `displayName (SB-
  <shortId>)`), and that id is different for the same real person in every
  separate Shedbooks deployment/database — each one generates its own
  UUIDs on import. Confirmed as a real incident, not a hypothetical: a dev
  and a production deployment both synced against this same live tenant,
  and production's very first run collided on email with contacts dev had
  already created for the identical real people under dev's own ids,
  because Name-based matching never recognized them as the same person.
  Email is the one thing Exchange itself already enforces as globally
  unique, so matching on it is robust no matter how many separate
  Shedbooks environments sync against the same tenant — the actual "many
  tenants, must be robust" requirement this fix was written for. The
  member's email (not the freshly-created object's Name-derived
  `.Identity`) is then used directly as `-Identity` for the immediately-
  following Set-MailContact/Set-Contact calls too — confirmed against the
  live tenant that an email address is a valid identity value (same as
  Name/Alias/DN/GUID) — since relying on a brand-new object's Name-based
  identity was separately observed to fail with "couldn't be found" on an
  object that had only just been created, apparently a directory-
  replication-timing issue distinct from the matching problem above.
  Skipping the orphan check entirely would create a fresh duplicate on
  every retry, and Exchange would then reject every same-email duplicate
  with an ambiguous "proxy address already in use" error. If more than one
  orphan is found (rare — state left over from before this check existed),
  it's reported as a per-member error asking for manual cleanup in
  Exchange rather than guessing which duplicate to keep.

  Set-Contact and Set-MailContact are NOT interchangeable and this script
  deliberately uses both: Set-Contact only exposes base AD contact
  properties (Notes, StreetAddress, Phone, ...) and has no
  CustomAttribute1-15 parameters on any tenant, for any caller — confirmed
  against the live tenant via `Get-Command Set-Contact -Syntax`.
  CustomAttribute1 (which carries the Shedbooks member id, used by the
  orphan lookup above) is a mail-enabled-recipient property and must go
  through Set-MailContact instead. An earlier version of this script
  splatted CustomAttribute1 into the Set-Contact call, which failed with
  "A parameter cannot be found that matches parameter name
  'CustomAttribute1'" for every single member, every time — the true
  reason no member had ever actually finished syncing, only discovered
  once the earlier setup-script issues (GUID-vs-domain, UnAuthorized) had
  been cleared and members could finally reach this line.

  A member with no syncable email address cannot have a mail contact
  created for it (ExternalEmailAddress must be a real SMTP address) and is
  reported as a per-member error rather than silently skipped — though in
  practice Shedbooks' own eligibility query excludes such members before
  they ever reach this script; the check here is a defensive backstop.

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
            # Belt-and-braces: Shedbooks' own eligibility query (server-side
            # Member.hasSyncableEmail) already excludes members without a
            # valid-looking email before they ever reach this script, but
            # check again here rather than letting Exchange reject a
            # malformed address (e.g. "N/A" typed into the field) with a
            # confusing SMTP-format error.
            if ($member.email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
                throw "Member's email address `"$($member.email)`" does not look like a valid email address."
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

            # Set-Contact and Set-MailContact split the recipient's fields
            # between them and are NOT interchangeable: Set-Contact only
            # knows the base AD contact properties (Notes, StreetAddress,
            # Phone, ...) — it has no CustomAttribute1-15 parameters at
            # all, on any tenant, for any caller (confirmed against the
            # live tenant: `Get-Command Set-Contact -Syntax` lists none).
            # CustomAttribute1 is a mail-enabled-recipient property, so it
            # must go through Set-MailContact instead. Splatting it into
            # Set-Contact's call — the original shape of this script — has
            # always failed with "A parameter cannot be found that matches
            # parameter name 'CustomAttribute1'", for every member, every
            # single time. It went unnoticed at first because members were
            # separately failing on other bugs before ever reaching this
            # call (the GUID-vs-domain and UnAuthorized issues in the
            # earlier setup-script saga); once those cleared, this was
            # revealed as the reason no member had ever actually finished
            # syncing (confirmed: `o365_contact_id` was NULL for all 73
            # members even after several successful-looking connections).
            $setContactParams = @{ Notes = $notes }
            if ($member.phone) { $setContactParams['Phone'] = $member.phone }
            if ($street) { $setContactParams['StreetAddress'] = $street }

            $identity = $null
            if ($member.existingContactId) {
                # Probe existence rather than matching Set-*'s error text —
                # error message wording is locale- and version-fragile.
                $existing = Get-MailContact -Identity $member.existingContactId -ErrorAction SilentlyContinue
                if ($existing) {
                    Set-MailContact -Identity $member.existingContactId `
                        -Name $internalName -DisplayName $displayName `
                        -ExternalEmailAddress $member.email `
                        -CustomAttribute1 $member.memberId -ErrorAction Stop | Out-Null
                    Set-Contact -Identity $member.existingContactId @setContactParams -ErrorAction Stop | Out-Null
                    $identity = $member.existingContactId
                }
                # else: stale id — contact was deleted directly in the GAL. Fall through to recreate.
            }

            if (-not $identity) {
                # No known id (first sync, or a stale one) — before creating,
                # check whether a contact for this exact member already
                # exists. Matched by EMAIL, not Name: Name embeds THIS
                # environment's own member id (SB-<shortId>), which is
                # different for the same real person in every separate
                # Shedbooks deployment/database — each one generates its own
                # UUIDs on import. Confirmed as a real incident: dev and
                # prod both synced against this same live tenant, and prod's
                # very first run collided on email with contacts dev had
                # already created for the identical people under dev's own
                # ids, since Name-based matching never recognized them as
                # the same person. Email is the one thing Exchange itself
                # already enforces as globally unique, so matching on it
                # works no matter which Shedbooks environment (or how many)
                # sync against the same tenant. `-Identity <email address>`
                # is a Microsoft-documented valid identity form (same as
                # Name/Alias/DN/GUID) — confirmed against the live tenant —
                # so it's used directly for the two Set-* calls below
                # instead of a freshly-created object's Name-based identity,
                # which was the separate cause of a "couldn't be found"
                # replication-lag error seen on a different member today.
                $orphaned = @(Get-MailContact -Filter "EmailAddresses -eq 'smtp:$($member.email)'" -ErrorAction SilentlyContinue)
                if ($orphaned.Count -gt 1) {
                    throw "Multiple existing GAL contacts already use the email '$($member.email)' — manual cleanup required in Exchange (Get-MailContact -Filter `"EmailAddresses -eq 'smtp:$($member.email)'`") before this member can sync."
                } elseif ($orphaned.Count -eq 1) {
                    Set-MailContact -Identity $member.email `
                        -Name $internalName -DisplayName $displayName `
                        -ExternalEmailAddress $member.email `
                        -CustomAttribute1 $member.memberId -ErrorAction Stop | Out-Null
                    Set-Contact -Identity $member.email @setContactParams -ErrorAction Stop | Out-Null
                    $identity = $member.email
                } else {
                    New-MailContact -Name $internalName -DisplayName $displayName `
                        -ExternalEmailAddress $member.email -ErrorAction Stop | Out-Null
                    Set-MailContact -Identity $member.email -CustomAttribute1 $member.memberId -ErrorAction Stop | Out-Null
                    Set-Contact -Identity $member.email @setContactParams -ErrorAction Stop | Out-Null
                    $identity = $member.email
                }
            }

            $result.contactId = $identity
        }
        catch {
            $result.error = "$($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())]"
        }
        $results += [pscustomobject]$result
        Write-PartialResults -Results $results
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

exit 0
