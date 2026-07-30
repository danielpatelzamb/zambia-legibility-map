# match_ncc_contacts.ps1
# Bulk-joins the NCC (National Council for Construction) contractor registers against the mineral
# licence register, to recover published business contacts for holders the web sweeps could not reach.
#
# WHY THESE EDITIONS: only the 2021 and 2023 registers carry PHYSICAL ADDRESS / TELEPHONE / MOBILE /
# EMAIL columns. The 2024, 2025 and 2026 editions replaced them with a mostly-empty POSTAL ADDRESS
# column - measured: 10,602 phones and 3,880 emails in 2021, 6,263 and 5,445 in 2023, versus ZERO in
# every later edition. Always target 2021 + 2023.
#
# Output is contact data, so it goes to private/ and is never published.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sc   = "C:\Users\-\AppData\Local\Temp\claude\C--Users---Downloads-Mining-project\e9498ec4-84af-4c22-b594-6598d752d74b\scratchpad"
$out  = Join-Path $root 'private\research\ncc_contact_matches.json'

function Norm([string]$n) {
    if (-not $n) { return '' }
    $x = ($n.ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b',' '
    ($x -replace '\s+',' ').Trim()
}

# ---------- parse an NCC register ----------
# Rows are space-padded columns:
#   COMPANY NAME | GRADE | CATEGORY | CLASSIFICATION | TOWN | PROVINCE | PHYSICAL ADDRESS | TELEPHONE | MOBILE | EMAIL
# Splitting on runs of 2+ spaces recovers the cells; a row may repeat per grade/category, so we keep
# the first row that actually carries a contact.
function Parse-NCC([string]$path, [string]$edition) {
    if (-not (Test-Path $path)) { Write-Warning "missing $path"; return @() }
    $recs = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($path)) {
        if ($line -notmatch '\S') { continue }
        if ($line -match 'COMPANY NAME\s+GRADE') { continue }
        $cells = @($line -split '\s{2,}' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($cells.Count -lt 2) { continue }
        $name = $cells[0]
        # a real row starts with a company-looking name, not a page artefact
        if ($name.Length -lt 4 -or $name -match '^(Page|NCC|REGISTER|Printed|\d+$)') { continue }
        $email = ([regex]::Match($line, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')).Value
        $phones = @([regex]::Matches($line, '\+?260\s?\d{2,3}\s?\d{3}\s?\d{3,4}|\b0[97]\d{8}\b') |
                    ForEach-Object { ($_.Value -replace '\s','') } | Select-Object -Unique)
        if (-not $email -and -not $phones.Count) { continue }
        $k = Norm $name
        if (-not $k -or $recs.ContainsKey($k)) { continue }
        # town/province sit in the middle cells; pick the recognisable ones
        $prov = ($cells | Where-Object { $_ -match '^(Copperbelt|Lusaka|Central|Southern|Northern|Eastern|Western|Luapula|Muchinga|North Western|North-Western)$' } | Select-Object -First 1)
        $town = $null
        for ($i=1; $i -lt $cells.Count; $i++) {
            if ($cells[$i] -eq $prov -and $i -ge 1) { $town = $cells[$i-1]; break }
        }
        $addr = ($cells | Where-Object { $_ -match '^\d+\s+\S' -or $_ -match '(?i)\b(plot|road|avenue|street|plaza|house|plt)\b' } | Select-Object -First 1)
        $recs[$k] = [pscustomobject]@{
            ncc_name = $name; edition = $edition
            town = $town; province = $prov; address = $addr
            phone = if ($phones.Count) { $phones -join ' / ' } else { $null }
            email = if ($email) { $email.ToLower() } else { $null }
        }
    }
    Write-Host ("  parsed {0}: {1} companies with a contact" -f $edition, $recs.Count)
    $recs
}

$n2023 = Parse-NCC (Join-Path $sc 'ncc2023.txt') 'NCC 2023'
$n2021 = Parse-NCC (Join-Path $sc 'ncc2021.txt') 'NCC 2021'

# ---------- the holder universe still lacking a channel ----------
$roster = Import-Csv (Join-Path $root 'research\holder_roster_all.csv')
$hcPath = Join-Path $root 'private\dataset\holder_contacts_v2.csv'
$reach = @{}
if (Test-Path $hcPath) {
    foreach ($r in (Import-Csv $hcPath)) { if ($r.reachable -eq 'yes') { $k = Norm $r.holder; if ($k) { $reach[$k] = 1 } } }
}
$want = @($roster | Where-Object { $_.holder_class -eq 'organization' -and -not $reach[(Norm $_.holder)] })
Write-Host ("`nholders still without a channel: {0}" -f $want.Count)

$hits = foreach ($h in $want) {
    $k = Norm $h.holder
    $m = if ($n2023.ContainsKey($k)) { $n2023[$k] } elseif ($n2021.ContainsKey($k)) { $n2021[$k] } else { $null }
    if (-not $m) { continue }
    [pscustomobject]@{
        holder = $h.holder
        ncc_name = $m.ncc_name
        matched_on = 'exact normalised name'
        edition = $m.edition
        phone = $m.phone; email = $m.email
        town = $m.town; province = $m.province; address = $m.address
        segment = $h.segment; licenses = $h.licenses; mining_lics = $h.mining_lics
        hectares = $h.hectares; main_commodities = $h.main_commodities
        lics_in_default_2025 = $h.lics_in_default_2025
        # NCC is a CONSTRUCTION register: a match proves the same legal name is a registered
        # contractor, which is strong but not proof the contact belongs to the mining operation.
        confidence = 'medium'
        note = 'Contact published in the NCC contractor register under an exact normalised name match. NCC registers construction contractors, so verify the entity is the same operation before relying on it.'
    }
}
$hits = @($hits)
$json = if ($hits.Count -eq 1) { '[' + ($hits[0] | ConvertTo-Json -Depth 5 -Compress) + ']' } else { $hits | ConvertTo-Json -Depth 5 }
[System.IO.File]::WriteAllText($out, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("`nMATCHES: {0} holders gained a published contact" -f $hits.Count)
Write-Host ("  with a phone: {0} | with an email: {1} | with a town: {2}" -f `
    @($hits | Where-Object { $_.phone }).Count, @($hits | Where-Object { $_.email }).Count, @($hits | Where-Object { $_.town }).Count)
Write-Host ("  holding a mining/processing licence: {0}" -f @($hits | Where-Object { [int]$_.mining_lics -gt 0 }).Count)
Write-Host ("  in the 2025 default notice: {0}" -f @($hits | Where-Object { [int]$_.lics_in_default_2025 -gt 0 }).Count)
Write-Host ("`nwrote {0}" -f $out)
$hits | Sort-Object { -[int]$_.hectares } | Select-Object -First 12 | ForEach-Object {
    Write-Host ("  {0,-42} {1,8} ha  {2}  {3}" -f $_.holder, $_.hectares, $_.phone, $_.email) }
