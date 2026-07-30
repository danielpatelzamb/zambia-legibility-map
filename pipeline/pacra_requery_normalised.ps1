# pacra_requery_normalised.ps1
# Second-pass PACRA lookup for holders whose first query returned nothing because the register's
# name string contains punctuation the search endpoint cannot handle.
#
# Verified cause: "VS Construction & Mining Services Limited" returns 0 hits, but querying
# "VS Construction" returns VS CONSTRUCTION & MINING SERVICES LIMITED (120080075175, Active,
# registered 2008, beneficial owners undeclared). The ampersand — and to a lesser extent dots,
# brackets, apostrophes and double spaces — breaks matching. 141 of the 559 "no registry match"
# holders carry such artefacts, so a meaningful share of that number is a query bug, not absence.
#
# Strategy per holder: try progressively simplified name forms, and only accept a hit whose
# registry name is genuinely similar to the original (token-overlap test) so that shortened
# queries cannot silently attach an unrelated company (e.g. "Anzan" -> "Anzanu Wholesalers").
param(
    [string]$Target = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\pacra_requery_target.csv'),
    [string]$Out    = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\pacra_requery_results.json'),
    [int]$DelayMs   = 250,
    [int]$SaveEvery = 15
)
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'

function Tokens([string]$n) {
    $x = ($n.ToUpper() -replace '[^A-Z0-9 ]', ' ') -replace '\s+', ' '
    $drop = @('LIMITED','LTD','PLC','COMPANY','CO','INCORPORATED','INC','THE','AND','OF')
    @($x.Trim() -split ' ' | Where-Object { $_ -and $drop -notcontains $_ })
}
# accept a candidate only if it shares most distinctive tokens with the original name
function IsSimilar([string]$orig, [string]$cand) {
    $a = Tokens $orig; $b = Tokens $cand
    if (-not $a.Count -or -not $b.Count) { return $false }
    $shared = @($a | Where-Object { $b -contains $_ }).Count
    ($shared / $a.Count) -ge 0.6
}
function Variants([string]$n) {
    $v = New-Object System.Collections.Generic.List[string]
    $v.Add(($n -replace '\s{2,}', ' ').Trim())
    $v.Add((($n -replace '&', ' ') -replace '\s+', ' ').Trim())        # drop ampersand
    $v.Add((($n -replace '[\.\(\)\''/,]', ' ') -replace '\s+', ' ').Trim())  # drop punctuation
    $t = Tokens $n
    if ($t.Count -ge 3) { $v.Add(($t[0..2]) -join ' ') }
    if ($t.Count -ge 2) { $v.Add(($t[0..1]) -join ' ') }
    if ($t.Count -ge 1) { $v.Add($t[0]) }
    @($v | Where-Object { $_.Length -ge 4 } | Select-Object -Unique)
}

$holders = @(Import-Csv $Target)
Write-Host "holders to re-query: $($holders.Count)"
$results = [System.Collections.Generic.List[object]]::new()
$seen = @{}
if (Test-Path $Out) { try { foreach ($r in (Get-Content $Out -Raw -Encoding UTF8 | ConvertFrom-Json)) { $results.Add($r); $seen[$r.query_holder]=$true }; Write-Host "resuming: $($results.Count)" } catch {} }
function Save-Out {
    $json = if ($results.Count -eq 1) { '[' + ($results[0] | ConvertTo-Json -Depth 5 -Compress) + ']' } else { $results | ConvertTo-Json -Depth 5 }
    [System.IO.File]::WriteAllText($Out, $json, [System.Text.Encoding]::UTF8)
}

$i=0; $resolved=0
foreach ($h in $holders) {
    $i++
    if ($seen[$h.holder]) { continue }
    $hit = $null; $usedVariant = $null; $rejected = @()
    foreach ($v in (Variants $h.holder)) {
        $u = "https://xatu.pacra.org.zm:8344/api/v1/Search/registrysearch?Searchtext=" + [uri]::EscapeDataString($v) + "&SortyBy=entity%20name&Direction=ASC"
        $rows = $null
        try { $rows = @(Invoke-RestMethod -Uri $u -UserAgent $ua -TimeoutSec 35) } catch {}
        if ($rows -and $rows.Count) {
            foreach ($e in $rows) {
                if (IsSimilar $h.holder $e.entityName) { $hit = $e; $usedVariant = $v; break }
                else { $rejected += $e.entityName }
            }
        }
        if ($hit) { break }
        Start-Sleep -Milliseconds $DelayMs
    }
    if ($hit) { $resolved++ }
    $results.Add([pscustomobject]@{
        query_holder = $h.holder; segment = $h.segment
        resolved = [bool]$hit
        matched_variant = $usedVariant
        entity_name = $hit.entityName; entity_number = $hit.entityNumber
        registration_date = $hit.registrationDate; entity_status = $hit.entityStatus
        nature_of_business = $hit.natureofBusiness; company_type = $hit.companyType
        annual_return_status = $hit.annualReturnStatus
        beneficial_owner_status = $hit.beneficialOwnerStatus
        nominal_capital_status = $hit.nominalCapitalStatus
        rejected_candidates = @($rejected | Select-Object -Unique -First 5)
        note = if ($hit) { "resolved via simplified query '$usedVariant'; original register string failed on punctuation" } else { 'no similar entity found under any name variant' }
    })
    $seen[$h.holder] = $true
    if (($i % $SaveEvery) -eq 0) { Save-Out; Write-Host ("  {0}/{1}  resolved {2}" -f $i, $holders.Count, $resolved) }
}
Save-Out
Write-Host "DONE. re-queried $($results.Count) | newly resolved: $resolved"
