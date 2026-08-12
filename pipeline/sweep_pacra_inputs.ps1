# sweep_pacra_inputs.ps1
# Sweeps the PACRA public companies-registry API for the INPUT side of mining: reagents and
# process chemicals, explosives, equipment and spares, grinding media, freight and haulage,
# fuel and power, assay and inspection, water and tailings, steel and fabrication.
#
# Why the registry rather than a directory: PACRA is the only source that covers every
# registered company, returns a company number and statutory standing, and can be queried by
# keyword. Commercial directories in Zambia are thin, stale, and not bulk-queryable (tested:
# zambiadirectory.com returns an identical 222 KB page for every query).
#
# Resumable: writes after every keyword, skips keywords already in the output. Safe to rerun.
# The API cannot handle '&' in a search term - keywords here are single words for that reason.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out  = Join-Path $root 'research\pacra_input_suppliers.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# category -> search keywords. Deliberately broad: a false positive is cheap to filter later,
# a missed supplier is invisible forever.
$KEYWORDS = [ordered]@{
    process_chemicals = @('REAGENT','CHEMICAL','SULPHURIC','FLOTATION','XANTHATE','FROTHER',
                          'CYANIDE','PEROXIDE','SOLVENT','LIME','LIMESTONE','FLOCCULANT','RESIN')
    explosives        = @('EXPLOSIVE','BLASTING','DETONATOR','NITRATE','PYROTECH')
    equipment         = @('MACHINERY','CONVEYOR','CRUSHER','EXCAVATOR','EARTHMOVING','SPARES',
                          'HYDRAULIC','BEARING','COMPRESSOR','GENERATOR','PUMPS')
    grinding_wear     = @('GRINDING','FOUNDRY','LINER','ABRASIVE','CASTING')
    freight_haulage   = @('FREIGHT','LOGISTICS','HAULAGE','FORWARDING','SHIPPING','TRUCKING','CARGO')
    fuel_power        = @('PETROLEUM','LUBRICANT','FUELS','SOLAR','ENERGY')
    assay_inspection  = @('ASSAY','LABORATORIES','INSPECTION','GEOCHEMICAL','SAMPLING','SURVEYORS')
    water_tailings    = @('DEWATERING','TAILINGS','EFFLUENT','BOREHOLE','PUMPING')
    steel_fabrication = @('FABRICATION','STEEL','ENGINEERING','WELDING','GALVANIZ')
    ppe_consumables   = @('PROTECTIVE','SAFETY','OVERALL','CONSUMABLES','LUBRICANTS')
}

# ISIC lines that indicate the company is plausibly in the physical supply chain rather than,
# say, a hair salon that happens to be called "Chemical Investments". Used to grade, not filter.
$RELEVANT_ISIC = 'manufactur|wholesale|retail sale|transport|freight|warehous|repair|install|' +
                 'mining|quarry|chemical|metal|machinery|engineer|technical testing|construction|' +
                 'petroleum|electricity|water|remediation|rubber|plastic|glass|cement'

$seen = @{}
$rows = New-Object System.Collections.Generic.List[object]
$doneKw = @{}
if (Test-Path $out) {
    $prev = @([System.IO.File]::ReadAllText($out, $utf8) | ConvertFrom-Json | ForEach-Object { $_ })
    foreach ($p in $prev) {
        $rows.Add($p); $seen[$p.entity_number] = 1
        foreach ($k in ($p.matched_keywords -split ',')) { $doneKw[$k.Trim()] = 1 }
    }
    Write-Host ("resuming: {0} companies already collected across {1} keywords" -f $rows.Count, $doneKw.Count)
}

function Save {
    # $rows is a generic List; ConvertTo-Json chokes on it directly under PS 5.1, and a
    # single-element array degrades to a bare object. ToArray() + explicit wrap handles both.
    $arr = $rows.ToArray()
    if ($arr.Count -eq 0) { return }
    $json = if ($arr.Count -eq 1) { '[' + ($arr[0] | ConvertTo-Json -Depth 4 -Compress) + ']' }
            else { $arr | ConvertTo-Json -Depth 4 }
    [System.IO.File]::WriteAllText($out, $json, $utf8)
}

$total = ($KEYWORDS.Values | ForEach-Object { $_ }).Count
$i = 0
$script:noContent = 0
foreach ($cat in $KEYWORDS.Keys) {
    foreach ($kw in $KEYWORDS[$cat]) {
        $i++
        if ($doneKw.ContainsKey($kw)) { continue }
        $uri = 'https://xatu.pacra.org.zm:8344/api/v1/Search/registrysearch?Searchtext=' +
               [uri]::EscapeDataString($kw) + '&SortyBy=entity%20name&Direction=ASC'
        # The API answers 204 No Content when it has nothing OR when it is throttling, and an
        # empty body deserialises to '' - which @() then counts as one phantom hit. Check the
        # status code, and treat a 204 on a keyword that should match as a throttle signal.
        try {
            $resp = Invoke-WebRequest -Uri $uri -TimeoutSec 60 -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Warning ("[{0}/{1}] {2} FAILED: {3}" -f $i, $total, $kw, $_.Exception.Message)
            Start-Sleep -Milliseconds 1500
            continue
        }
        if ($resp.StatusCode -eq 204 -or -not $resp.RawContentLength) {
            Write-Host ("[{0,3}/{1}] {2,-18} {3,-14} 204 no content" -f $i, $total, $cat, $kw)
            $script:noContent++
            if ($script:noContent -ge 8 -and $rows.Count -eq 0) {
                throw ("PACRA returned 204 for the first {0} keywords with zero results. The endpoint " +
                       "is throttling or has changed - verify by hand with a name that must exist " +
                       "(e.g. Searchtext=KANSANSHI) before rerunning. Nothing was written." -f $script:noContent)
            }
            Start-Sleep -Milliseconds 400
            continue
        }
        $body = [Text.Encoding]::UTF8.GetString($resp.Content)
        $hits = @(($body | ConvertFrom-Json) | ForEach-Object { $_ })
        $new = 0
        foreach ($h in $hits) {
            $num = "$($h.entityNumber)"
            if (-not $num) { continue }
            if ($seen.ContainsKey($num)) {
                # already found under another keyword - record the extra keyword, don't duplicate
                $ex = $rows | Where-Object { $_.entity_number -eq $num } | Select-Object -First 1
                if ($ex -and ($ex.matched_keywords -notmatch [regex]::Escape($kw))) {
                    $ex.matched_keywords = ($ex.matched_keywords + ', ' + $kw)
                    if ($ex.categories -notmatch [regex]::Escape($cat)) { $ex.categories = ($ex.categories + ', ' + $cat) }
                }
                continue
            }
            $isic = "$($h.isicClasification)"
            $rows.Add([pscustomobject]@{
                name              = "$($h.entityName)"
                entity_number     = $num
                registered        = "$($h.registrationDate)"
                status            = "$($h.entityStatus)"
                nature_of_business= "$($h.natureofBusiness)"
                isic              = $isic
                bo_declared       = "$($h.beneficialOwnerStatus)"
                returns_filed     = "$($h.annualReturnStatus)"
                categories        = $cat
                matched_keywords  = $kw
                isic_plausible    = [bool]($isic -match $RELEVANT_ISIC)
            })
            $seen[$num] = 1; $new++
        }
        Write-Host ("[{0,3}/{1}] {2,-14} {3,-14} {4,4} hits, {5,4} new  (total {6})" -f `
            $i, $total, $cat, $kw, $hits.Count, $new, $rows.Count)
        Save
        Start-Sleep -Milliseconds 250
    }
}

Save
Write-Host ("`nDONE: {0} distinct companies" -f $rows.Count)
Write-Host ("  active: {0} | ISIC plausible for a supply-chain role: {1}" -f `
    @($rows | Where-Object { $_.status -eq 'Active' }).Count,
    @($rows | Where-Object { $_.isic_plausible }).Count)
Write-Host "`nby category:"
$rows | Group-Object categories | Sort-Object Count -Descending | Select-Object -First 15 |
    ForEach-Object { Write-Host ("  {0,5}  {1}" -f $_.Count, $_.Name) }
Write-Host ("`nwrote {0}" -f $out)
