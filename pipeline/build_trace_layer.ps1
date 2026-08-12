# build_trace_layer.ps1
# Builds data/trace_data.js - the supply-chain visibility layer: which counterparties are
# verified under which standards, and the customs-manifest evidence that proves physical flows.
#
# "Verified" here means VERIFIABLE AGAINST A NAMED PUBLIC RECORD, standard by standard - not a
# blanket endorsement. Each flag carries its source so a user can re-check it. Standards where
# our evidence is a published list we could not re-query live (LME brands, ISO 17025 labs) are
# marked check:'verify' and rendered differently in the app.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$ds   = Join-Path $root 'dataset'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Norm([string]$n) {
    if (-not $n) { return '' }
    # Strip parentheticals first: "Lumwana Mining Company (Barrick)" and "Lumwana Mining Co Ltd"
    # are the same counterparty, and leaving the qualifier in produced duplicate rows.
    $x = ($n -replace '\([^)]*\)','')
    $x = ($x.ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE|MINES|MINE|MINING)\b',' '
    ($x -replace '\s+',' ').Trim()
}

# ---------- evidence sources ----------
$pacra = @{}   # norm name -> @{bo=..; ar=..}
foreach ($r in (Import-Csv (Join-Path $ds 'pacra_registry.csv'))) {
    $k = Norm $r.entity_name
    if ($k -and -not $pacra.ContainsKey($k)) {
        $pacra[$k] = @{ bo = ($r.beneficial_owner_declared -eq '1'); ar = ($r.annual_return_filed -eq '1'); num = $r.entity_number }
    }
}

$zeiti = @{}   # entities appearing in ZEITI/EITI reconciliation = they report payments
foreach ($r in (Import-Csv (Join-Path $ds 'entity_values_zeiti.csv'))) { $zeiti[(Norm $r.entity_as_published)] = 1 }
foreach ($r in (Import-Csv (Join-Path $ds 'entity_values.csv'))) {
    if ($r.source_name -match 'ZEITI|EITI') { $zeiti[(Norm $r.entity)] = 1 }
}

$bol = @{}     # shippers with a US CBP sea-manifest record  (physical flow, third-country customs data)
$bolRows = @(Import-Csv (Join-Path $ds 'bol_shipments.csv'))
foreach ($r in $bolRows) { $k = Norm (($r.shipper -split '\(')[0]); if ($k) { $bol[$k] = 1 } }

# LME-listed Zambian copper brands - from the LME's published approved-brands list.
# We could not re-query the list live in this pass, so these carry check:'verify'.
# Keys MUST go through Norm(), or a change to Norm silently drops the flag - which it did once.
$lme = @{}
foreach ($e in @(@('Mopani Copper Mines Plc', 'brand MCM'), @('Konkola Copper Mines Plc', 'brand KCM'))) {
    $lme[(Norm $e[0])] = $e[1]
}

# ---------- the partner set: majors + facilities + chain counterparties + key service firms ----------
$ents  = @(Import-Csv (Join-Path $ds 'entities.csv'))
$facs  = @(Import-Csv (Join-Path $ds 'facilities.csv'))
$links = @(Import-Csv (Join-Path $ds 'supply_chain_links.csv'))
$biz   = @(Import-Csv (Join-Path $ds 'mining_businesses.csv'))

$partners = @{}
function AddPartner($name, $role, $seg, $eid) {
    $k = Norm $name
    if (-not $k -or $partners.ContainsKey($k)) { return }
    $p = $pacra[$k]
    $flags = [ordered]@{
        pacra = if ($p) { [bool]$p.bo } else { $false }
        eiti  = [bool]$zeiti[$k]
        bol   = [bool]$bol[$k]
        lme   = $lme.Contains($k)
    }
    $partners[$k] = [pscustomobject]@{
        name = $name; role = $role; seg = $seg; eid = $eid
        flags = $flags
        lmeNote = if ($lme.Contains($k)) { $lme[$k] } else { $null }
        pacraNum = if ($p) { $p.num } else { $null }
        score = @($flags.Values | Where-Object { $_ }).Count
    }
}
foreach ($e in $ents)  { AddPartner $e.canonical_name 'producer' 'mining' $e.entity_id }
foreach ($f in $facs)  { AddPartner $f.operator ('facility: ' + $f.facility_type) 'processing' $f.operator_entity_id }
foreach ($l in $links) { AddPartner $l.entity ('chain: ' + $l.link_type) $l.commodity $l.entity_id }
# service layer: assay labs and collateral managers are the verification infrastructure itself
foreach ($b in ($biz | Where-Object { $_.segment -in 'assay_lab','freight_clearing','smelter_refiner','processor' -and $_.pacra_status -eq 'Active' })) {
    AddPartner $b.name ('service: ' + $b.segment) $b.segment $null
}
$plist = @($partners.Values | Sort-Object { -$_.score }, name)
Write-Host ("partners: {0}  (score>=2: {1}, score>=1: {2})" -f $plist.Count,
    @($plist | Where-Object score -ge 2).Count, @($plist | Where-Object score -ge 1).Count)

# ---------- BoL evidence rows (already public US customs data) ----------
$bolOut = foreach ($r in $bolRows) {
    [pscustomobject]@{
        d = $r.date; sh = ($r.shipper -split '\(')[0].Trim(); co = ($r.consignee -split ',')[0].Trim()
        p = $r.product; hs = $r.hs_code; kg = $r.weight_kg; o = $r.origin; de = $r.destination; u = $r.url
    }
}

# ---------- emit ----------
$STANDARDS = @'
{
 "pacra": {"n":"Beneficial ownership declared","w":"Ownership chain is on the public companies registry","s":"PACRA registry API","check":"live"},
 "eiti":  {"n":"EITI-reporting","w":"Discloses payments to government under the EITI standard, reconciled by an independent administrator","s":"ZEITI reconciliation reports","check":"live"},
 "bol":   {"n":"Customs-verified exporter","w":"Named shipper on US CBP sea import manifests - physical flow verified by a third country''s customs","s":"US CBP AMS via ImportYeti","check":"live"},
 "lme":   {"n":"LME-registered brand","w":"Cathode brand approved for delivery against LME contracts - the strongest quality/provenance signal in copper","s":"LME approved brand list","check":"verify"}
}
'@

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('/* trace_data.js - generated by pipeline/build_trace_layer.ps1. Do not hand-edit.')
[void]$sb.AppendLine('   Standards-verified counterparties and customs-manifest evidence. No contact data. */')
[void]$sb.AppendLine('window.TRACE = {')
[void]$sb.AppendLine('STANDARDS: ' + ($STANDARDS -replace "''","'") + ',')
[void]$sb.Append('PARTNERS: ')
[void]$sb.Append((ConvertTo-Json @($plist | ForEach-Object {
    [ordered]@{ n = $_.name; r = $_.role; seg = $_.seg; eid = $_.eid
                f = $_.flags; note = $_.lmeNote; num = $_.pacraNum; sc = $_.score }
}) -Depth 5 -Compress))
[void]$sb.AppendLine(',')
[void]$sb.Append('BOL: ')
[void]$sb.Append((ConvertTo-Json $bolOut -Depth 3 -Compress))
[void]$sb.AppendLine('};')

$out = Join-Path $root 'data\trace_data.js'
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
Write-Host ("wrote {0}  ({1:N0} KB)" -f $out, ((Get-Item $out).Length / 1kb))
