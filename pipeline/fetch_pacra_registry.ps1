# fetch_pacra_registry.ps1
# Queries PACRA's public (undocumented, unauthenticated) registry search API for every holder in
# the licence register and writes research/pacra_registry.json.
#
# Discovered 2026-07-28. Endpoint returns, per matched entity: entityName, entityNumber
# (registration no.), registrationDate, natureofBusiness, entityStatus, companyType, ISIC
# classification, and — most valuable for this project — annualReturnStatus and
# beneficialOwnerStatus with their statutory reason text. No contact fields are exposed.
#
# Politeness: sequential with a delay; this is a government service, not a scrape target.
# Resumable: skips holders already present in the output file, so it can be re-run after a crash.
param(
    [string]$Roster = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\holder_roster_all.csv'),
    [string]$Out    = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\pacra_registry.json'),
    [int]$DelayMs   = 250,
    [int]$SaveEvery = 25
)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'

$holders = @(Import-Csv $Roster | Where-Object { $_.holder_class -eq 'organization' })
Write-Host "organizations to query: $($holders.Count)"

# resume support
$results = [System.Collections.Generic.List[object]]::new()
$seen = @{}
if (Test-Path $Out) {
    try {
        foreach ($r in (Get-Content $Out -Raw -Encoding UTF8 | ConvertFrom-Json)) {
            $results.Add($r); $seen[$r.query_holder] = $true
        }
        Write-Host "resuming: $($results.Count) already done"
    } catch { Write-Host "existing output unreadable, starting fresh" }
}

function Save-Out {
    $json = if ($results.Count -eq 1) { '[' + ($results[0] | ConvertTo-Json -Depth 6 -Compress) + ']' }
            else { $results | ConvertTo-Json -Depth 6 }
    [System.IO.File]::WriteAllText($Out, $json, [System.Text.Encoding]::UTF8)
}

$i = 0; $hits = 0; $errs = 0
foreach ($h in $holders) {
    $i++
    if ($seen[$h.holder]) { continue }
    $q = [uri]::EscapeDataString($h.holder)
    $u = "https://xatu.pacra.org.zm:8344/api/v1/Search/registrysearch?Searchtext=$q&SortyBy=entity%20name&Direction=ASC"
    $rows = $null
    try { $rows = @(Invoke-RestMethod -Uri $u -UserAgent $ua -TimeoutSec 35) } catch { $errs++ }
    if ($rows -and $rows.Count) {
        $hits++
        foreach ($e in $rows) {
            $results.Add([pscustomobject]@{
                query_holder          = $h.holder
                segment               = $h.segment
                entity_name           = $e.entityName
                entity_number         = $e.entityNumber
                registration_date     = $e.registrationDate
                nature_of_business    = $e.natureofBusiness
                entity_status         = $e.entityStatus
                company_type          = $e.companyType
                isic_classification   = $e.isicClasification
                annual_return_status  = $e.annualReturnStatus
                annual_return_reason  = $e.annualReturnReason
                beneficial_owner_status = $e.beneficialOwnerStatus
                beneficial_owner_reason = $e.beneficialOwnerReason
                nominal_capital_status  = $e.nominalCapitalStatus
                nominal_capital_reason  = $e.nominalCapitalReason
                exact_name_match      = ($e.entityName -and ($e.entityName.Trim().ToUpper() -eq $h.holder.Trim().ToUpper()))
            })
        }
    } else {
        $results.Add([pscustomobject]@{
            query_holder = $h.holder; segment = $h.segment; entity_name = $null
            entity_number = $null; registration_date = $null; nature_of_business = $null
            entity_status = 'NO_REGISTRY_MATCH'; company_type = $null; isic_classification = $null
            annual_return_status = $null; annual_return_reason = $null
            beneficial_owner_status = $null; beneficial_owner_reason = $null
            nominal_capital_status = $null; nominal_capital_reason = $null
            exact_name_match = $false
        })
    }
    $seen[$h.holder] = $true
    if (($i % $SaveEvery) -eq 0) { Save-Out; Write-Host ("  {0}/{1}  hits {2}  errs {3}" -f $i, $holders.Count, $hits, $errs) }
    Start-Sleep -Milliseconds $DelayMs
}
Save-Out
Write-Host "DONE. records: $($results.Count)  queries with a match: $hits  errors: $errs"
