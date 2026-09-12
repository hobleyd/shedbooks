<#
.SYNOPSIS
  Lists Microsoft 365 license SKUs in the tenant that have at least one
  spare (unassigned) seat, via Microsoft Graph app-only (certificate-based)
  authentication.

.DESCRIPTION
  Invoked by ExchangeOnlineMailboxService.listAvailableLicenses
  (server/lib/infrastructure/services/exchange_online_mailbox_service.dart)
  before the admin picks a license to assign a newly created mailbox — see
  create_o365_mailbox.ps1 in this same directory.

  Requires the app registration to hold the Microsoft Graph *application*
  permission `Organization.Read.All` with admin consent — a separate grant
  from the Exchange RBAC roles ("Mail Recipients", "Distribution Groups",
  "Mail Recipient Creation") used elsewhere in this codebase. Exchange RBAC
  and Graph API permissions are independent grant systems; neither implies
  the other (see setup_exchange_rbac.ps1's own note on this).

.PARAMETER ConfigPath
  Path to the JSON input file: { tenantId, appId, certificatePath, certificatePassword }

.PARAMETER OutputPath
  Path to write the JSON results file to:
  { licenses: [ { skuId, skuPartNumber, availableUnits }, ... ] }
  Only SKUs with availableUnits > 0 are included. Only written after a
  successful connection — its absence tells the caller the whole session
  failed (bad certificate, module missing, network failure), as distinct
  from the tenant simply having zero licenses with spare seats (which is a
  valid, present-but-empty result).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop

try {
    $securePassword = ConvertTo-SecureString -String $config.certificatePassword -AsPlainText -Force
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $config.certificatePath, $securePassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)

    Connect-MgGraph -TenantId $config.tenantId -ClientId $config.appId -Certificate $cert -NoWelcome -ErrorAction Stop
}
catch {
    # Deliberately no results file — see .PARAMETER OutputPath above.
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

try {
    $skus = @(Get-MgSubscribedSku -All -ErrorAction Stop)

    $licenses = $skus | ForEach-Object {
        $enabled = $_.PrepaidUnits.Enabled
        $consumed = $_.ConsumedUnits
        $available = $enabled - $consumed
        if ($available -gt 0) {
            [ordered]@{
                skuId          = $_.SkuId
                skuPartNumber  = $_.SkuPartNumber
                availableUnits = $available
            }
        }
    } | Where-Object { $_ }

    $payload = [ordered]@{ licenses = @($licenses) }
    $json = $payload | ConvertTo-Json -Depth 6
    Set-Content -Path $OutputPath -Value $json -Encoding utf8
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

exit 0
