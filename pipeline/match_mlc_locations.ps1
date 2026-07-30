# match_mlc_locations.ps1
# Bulk-joins the MMMD Mining Licensing Committee results notices against the licence register to give
# every holder a district/province and a committee decision.
#
# Contacts are not in these notices - location and decision are. That is still the single most valuable
# thing available for the deep register: 94% of holders have no publishable contact, but knowing the
# district makes them reachable through the district mining office and the provincial bureau, which is
# how outreach to this population actually works.
#
# Source: MLC results notices, meetings 70-91 plus the extraordinary sitting and the enforcement
# notices, already extracted to a TSV by earlier passes. Columns:
#   page_id | notice_title | seq | licence_code | holder(with share) | province | decision | date
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sc   = "C:\Users\-\AppData\Local\Temp\claude\C--Users---Downloads-Mining-project\e9498ec4-84af-4c22-b594-6598d752d74b\scratchpad"
$out  = Join-Path $root 'research\mlc_holder_locations.json'

function Norm([string]$n) {
    if (-not $n) { return '' }
    $x = (($n -replace '\s*\(\d+(\.\d+)?%\)','').ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b',' '
    ($x -replace '\s+',' ').Trim()
}

# prefer the larger extract, fall back to the other
$srcs = @('mlc_rows.tsv','b3_mlc_rows.tsv') | ForEach-Object { Join-Path $sc $_ } | Where-Object { Test-Path $_ }
if (-not $srcs) { throw "no MLC extract found in the scratchpad" }

$byHolder = @{}
$rowCount = 0
foreach ($src in $srcs) {
    foreach ($line in [System.IO.File]::ReadAllLines($src)) {
        $c = $line -split "`t"
        if ($c.Count -lt 7) { continue }
        $code = $c[3]; $holder = $c[4]
        if ($code -notmatch '^\d{3,6}-HQ-[A-Z]{2,4}$') { continue }
        $k = Norm $holder
        if (-not $k) { continue }
        $rowCount++
        # Column positions are NOT stable across notices - some rows carry commodities ("Au", "Ag") or a
        # decision in the position where others carry the province. Never trust the index: scan every
        # cell for a value that is actually one of Zambia's ten provinces, and take the district only
        # from the same cell. Anything unmatched stays null rather than becoming a fake location.
        $PROV = 'Central|Copperbelt|Eastern|Luapula|Lusaka|Muchinga|Northern|North[\s\-]?Western|Southern|Western'
        $province = $null; $district = $null
        foreach ($cell in $c) {
            $t = ($cell -replace ',\s*$','').Trim()
            if (-not $t) { continue }
            if ($t -match "^($PROV)$") { $province = $Matches[1]; break }
            if ($t -match "^($PROV)\s*,\s*(.+)$") { $province = $Matches[1]; $district = $Matches[2].Trim(); break }
            if ($t -match "^(.+?)\s*,\s*($PROV)$") { $district = $Matches[1].Trim(); $province = $Matches[2]; break }
        }
        # decision: take it from a cell that looks like a decision verb, not by position
        $dec = ($c | Where-Object { $_ -match '^(Approved|Granted|Refused|Deferred|Cancelled|Rejected|Default(ed)?|Withdrawn|Pending)\b' } | Select-Object -First 1)
        if ($dec) { $dec = $dec.Trim() }
        if (-not $byHolder.ContainsKey($k)) {
            $byHolder[$k] = [pscustomobject]@{
                holder_as_published = ($holder -replace '\s*\(\d+(\.\d+)?%\)','').Trim()
                licence_codes = New-Object System.Collections.Generic.List[string]
                provinces = New-Object System.Collections.Generic.List[string]
                districts = New-Object System.Collections.Generic.List[string]
                decisions = New-Object System.Collections.Generic.List[string]
                notice = $c[1]
                page_id = $c[0]
            }
        }
        $rec = $byHolder[$k]
        if ($code -and -not $rec.licence_codes.Contains($code)) { $rec.licence_codes.Add($code) }
        if ($province -and -not $rec.provinces.Contains($province)) { $rec.provinces.Add($province) }
        if ($district -and -not $rec.districts.Contains($district)) { $rec.districts.Add($district) }
        if ($dec -and -not $rec.decisions.Contains($dec)) { $rec.decisions.Add($dec) }
    }
}
Write-Host ("parsed {0} MLC rows -> {1} distinct holders in the notices" -f $rowCount, $byHolder.Count)

# join to the register
$roster = Import-Csv (Join-Path $root 'research\holder_roster_all.csv')
$hits = foreach ($h in $roster) {
    $k = Norm $h.holder
    if (-not $byHolder.ContainsKey($k)) { continue }
    $m = $byHolder[$k]
    [pscustomobject]@{
        holder = $h.holder
        holder_class = $h.holder_class
        licence_codes = ($m.licence_codes -join ' | ')
        province = ($m.provinces -join ' | ')
        district = ($m.districts -join ' | ')
        decisions = ($m.decisions -join ' | ')
        segment = $h.segment
        licenses = $h.licenses
        hectares = $h.hectares
        main_commodities = $h.main_commodities
        source_notice = $m.notice
        source_url = if ($m.page_id -match '^p(\d+)$') { "https://www.mmmd.gov.zm/?p=" + $Matches[1] } else { $null }
    }
}
$hits = @($hits)
$json = if ($hits.Count -eq 1) { '[' + ($hits[0] | ConvertTo-Json -Depth 4 -Compress) + ']' } else { $hits | ConvertTo-Json -Depth 4 }
[System.IO.File]::WriteAllText($out, $json, (New-Object System.Text.UTF8Encoding($false)))

$orgs = @($roster | Where-Object holder_class -eq 'organization').Count
$ppl  = @($roster | Where-Object holder_class -eq 'person_or_unclassified').Count
Write-Host ("`nLOCATED via MLC notices: {0} of {1} holders in the register ({2}%)" -f `
    $hits.Count, $roster.Count, [math]::Round(100*$hits.Count/$roster.Count,1))
Write-Host ("  organisations: {0} of {1}" -f @($hits | Where-Object holder_class -eq 'organization').Count, $orgs)
Write-Host ("  individuals  : {0} of {1}" -f @($hits | Where-Object holder_class -eq 'person_or_unclassified').Count, $ppl)
Write-Host ("  with a district: {0} | with a province: {1}" -f `
    @($hits | Where-Object { $_.district }).Count, @($hits | Where-Object { $_.province }).Count)
Write-Host ("`nwrote {0}" -f $out)
Write-Host "`ntop provinces:"
$hits | Where-Object { $_.province -and $_.province -notmatch '\|' } | Group-Object province |
  Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { Write-Host ("  {0,5}  {1}" -f $_.Count, $_.Name) }
