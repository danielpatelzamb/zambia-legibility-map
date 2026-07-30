# build_analysis_dataset.ps1
# Flattens all repo data (EITI production, NGDR licenses, MMMD adverse lists, ZambiaLII court
# hits, UN Comtrade flows) into analysis-ready CSVs under dataset/. Research-agent outputs in
# research/ (contacts, facilities, BoL, entity values) are merged by merge_research_outputs.ps1.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out  = Join-Path $root 'dataset'
New-Item -ItemType Directory -Force $out | Out-Null

# ---------- entity crosswalk ----------
# canonical_id -> @{name; type; parent; variants (normalized: uppercase, "(100%)" stripped)}
function Normalize-Name([string]$n) {
    if (-not $n) { return '' }
    ($n -replace '\(100%\)', '' -replace '\s+', ' ').Trim().ToUpperInvariant()
}
# ownership_nationality: controlling shareholder's home country bloc (empirical, from published
# ownership); parent_country: parent HQ country. ZCCM-IH minority stakes exist in most producers.
$entities = @(
    @{id='KANSANSHI';        name='Kansanshi Mining Plc';            type='producer';  parent='First Quantum Minerals Ltd'; nat='Canada';        variants=@('KANSANSHI MINING PLC','KANSANSHI')}
    @{id='FQM_TRIDENT';      name='FQM Trident Ltd (Sentinel, ex-Kalumbila Minerals)'; type='producer'; parent='First Quantum Minerals Ltd'; nat='Canada'; variants=@('FQM TRIDENT','FQM TRIDENT LIMITED','KALUMBILA MINERALS LIMITED','KALUMBILA')}
    @{id='KCM';              name='Konkola Copper Mines Plc';        type='producer';  parent='Vedanta Resources Ltd';      nat='India/UK';      variants=@('KONKOLA COPPER MINES','KONKOLA COPPER MINES PLC')}
    @{id='MOPANI';           name='Mopani Copper Mines Plc';         type='producer';  parent='International Resources Holding (IRH)'; nat='UAE'; variants=@('MOPANI','MOPANI COPPER MINES PLC')}
    @{id='CCS';              name='Chambishi Copper Smelter Ltd';    type='smelter';   parent='CNMC / Yunnan Copper';       nat='China (state)'; variants=@('CHAMBISHI COPPER SMELTER LIMITED')}
    @{id='CHAMBISHI_METALS'; name='Chambishi Metals Plc';            type='smelter';   parent='ERG Africa';                 nat='Kazakhstan/Luxembourg'; variants=@('CHAMBISHI METALS PLC')}
    @{id='CNMC_LUANSHYA';    name='CNMC Luanshya Copper Mines Plc';  type='producer';  parent='CNMC';                       nat='China (state)'; variants=@('CNMC LUANSHYA COPPER MINES','CNMC LUANSHYA COPPER MINES PLC')}
    @{id='NFCA';             name='NFC Africa Mining Plc';           type='producer';  parent='CNMC';                       nat='China (state)'; variants=@('NFC AFRICA MINING PLC')}
    @{id='SINO_METALS';      name='Sino-Metals Leach Zambia Ltd';    type='producer';  parent='CNMC';                       nat='China (state)'; variants=@('SINO-METALS LEACH ZAMBIA LIMITED')}
    @{id='LUMWANA';          name='Lumwana Mining Co Ltd';           type='producer';  parent='Barrick Mining Corp';        nat='Canada';        variants=@('LUMWANA','LUMWANA MINING CO. LIMITED','LUMWANA MINING COMPANY LIMITED')}
    @{id='LUBAMBE';          name='Lubambe Copper Mine Ltd';         type='producer';  parent='EMR Capital (sale to JCHX pending/completed)'; nat='Australia -> China'; variants=@('LUBAMBE','LUBAMBE COPPER MINE LIMITED')}
    @{id='CHIBULUMA';        name='Chibuluma Mines Plc';             type='producer';  parent='Jinchuan Group';             nat='China (state)'; variants=@('CHIBULUMA MINES PLC')}
    @{id='MIMBULA';          name='Mimbula Minerals Ltd';            type='producer';  parent='Moxico Resources Plc';       nat='UK';            variants=@('MIMBULA MINERALS','MIMBULA MINERALS LIMITED')}
    @{id='ZCCM_IH';          name='ZCCM Investments Holdings Plc';   type='holding';   parent='IDC / GRZ';                  nat='Zambia (state)';variants=@('ZCCM INVESTMENTS HOLDINGS PLC','ZCCM-IH')}
    @{id='ZAMEFA';           name='Metal Fabricators of Zambia Plc'; type='fabricator';parent='Reunert Ltd';                nat='South Africa';  variants=@('METAL FABRICATORS OF ZAMBIA PLC','ZAMEFA')}
    @{id='OTHER_MINES';      name='Other mines (EITI aggregate)';    type='aggregate'; parent=$null;                        nat=$null;           variants=@('OTHER MINES')}
)
$variantMap = @{}
foreach ($e in $entities) { foreach ($v in $e.variants) { $variantMap[$v] = $e.id } }
function Resolve-Entity([string]$raw) {
    $n = Normalize-Name $raw
    if ($variantMap.ContainsKey($n)) { $variantMap[$n] } else { $null }
}
$entities | ForEach-Object {
    [pscustomobject]@{ entity_id=$_.id; canonical_name=$_.name; entity_type=$_.type; parent_company=$_.parent;
        ownership_nationality=$_.nat; name_variants=($_.variants -join '|') }
} | Export-Csv (Join-Path $out 'entities.csv') -NoTypeInformation -Encoding UTF8

# ---------- entity production (EITI) ----------
$prod = Get-Content (Join-Path $root 'data\gov\production\production.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$prod.companyProduction | ForEach-Object {
    [pscustomobject]@{
        entity_id = Resolve-Entity $_.company
        company_as_published = $_.company
        mine = $_.mine
        commodity = $_.commodity
        year = $_.year
        volume = $_.volume
        unit = $_.unit
        source = $_.source
    }
} | Export-Csv (Join-Path $out 'entity_production.csv') -NoTypeInformation -Encoding UTF8

$prod.nationalProductionByCommodity | ForEach-Object {
    [pscustomobject]@{ commodity=$_.commodity; year=$_.year; volume=$_.volume; unit_note=$_.unit; source=$_.source }
} | Export-Csv (Join-Path $out 'national_production.csv') -NoTypeInformation -Encoding UTF8

$prod.exportsByCommodity | ForEach-Object {
    [pscustomobject]@{ commodity=$_.commodity; hs_code=$_.hsCode; year=$_.year; volume=$_.volume; unit=$_.unit;
        value_usd=$_.valueUsd; value_zmw=$_.valueZmw; customs_transactions=$_.transactions; source=$_.source }
} | Export-Csv (Join-Path $out 'exports_by_commodity.csv') -NoTypeInformation -Encoding UTF8

# 2023 USD production values from ZEITI (production_data.js companies[].usd2023)
$pdKeyMap = @{ CCS='CCS'; KALUMBILA='FQM_TRIDENT'; KANSANSHI='KANSANSHI'; LUMWANA='LUMWANA'; NFCA='NFCA';
    MOPANI='MOPANI'; LUANSHYA='CNMC_LUANSHYA'; KCM='KCM'; OTHER='OTHER_MINES'; LUBAMBE='LUBAMBE';
    CHIBULUMA='CHIBULUMA'; MIMBULA='MIMBULA' }
$pdLines = Get-Content (Join-Path $root 'data\production_data.js') -Encoding UTF8 |
    Where-Object { $_ -match '^\{"key"' }
$pdLines | ForEach-Object { $_.TrimEnd(',') | ConvertFrom-Json } | Where-Object { $_.usd2023 } | ForEach-Object {
    [pscustomobject]@{
        entity_id = $pdKeyMap[$_.key]
        entity_as_published = $_.display
        year = 2023
        metric = 'production_value_usd'
        value = $_.usd2023
        unit = 'USD'
        source = 'ZEITI Copper Production by Company 2023 XLSX (via data/production_data.js)'
    }
} | Export-Csv (Join-Path $out 'entity_values_zeiti.csv') -NoTypeInformation -Encoding UTF8

# ---------- trade flows (UN Comtrade) ----------
$partnerNames = @{ 0='World'; 156='China'; 180='DR Congo'; 276='Germany'; 344='China, Hong Kong SAR'; 356='India';
    392='Japan'; 404='Kenya'; 410='Rep. of Korea'; 458='Malaysia'; 490='Other Asia, nes (Taiwan)'; 508='Mozambique';
    516='Namibia'; 528='Netherlands'; 682='Saudi Arabia'; 702='Singapore'; 704='Viet Nam'; 710='South Africa';
    716='Zimbabwe'; 756='Switzerland'; 764='Thailand'; 784='United Arab Emirates'; 792='Türkiye'; 800='Uganda';
    818='Egypt'; 826='United Kingdom'; 834='Tanzania'; 840='USA'; 894='Zambia'; 24='Angola'; 454='Malawi' }
$hsNames = @{ '740311'='Copper cathodes (refined)'; '2603'='Copper ores and concentrates'; '7402'='Unrefined copper / anodes';
    '7404'='Copper waste and scrap'; '7408'='Copper wire'; '8105'='Cobalt mattes and articles' }
$td = Get-Content (Join-Path $root 'data\trade_data.js') -Raw -Encoding UTF8
$i = $td.IndexOf('window.TRADE_ROWS = ')
$json = $td.Substring($i + 20).Trim().TrimEnd(';')
$rows = $json | ConvertFrom-Json
$rows | ForEach-Object {
    [pscustomobject]@{
        freq = $_.freq; period = $_.period; flow = $_.flow
        reporter_code = $_.rep; reporter = $partnerNames[[int]$_.rep]
        partner_code = $_.par;  partner  = $partnerNames[[int]$_.par]
        hs_code = $_.code; hs_desc = $hsNames[[string]$_.code]
        net_weight_kg = $_.kg; trade_value_usd = $_.usd
        source = 'UN Comtrade public preview API (fetched 2026-07-23)'
    }
} | Export-Csv (Join-Path $out 'trade_flows.csv') -NoTypeInformation -Encoding UTF8

# ---------- licenses (NGDR) + adverse flags ----------
$lp = Get-Content (Join-Path $root 'data\licenses_points.js') -Raw -Encoding UTF8
$i = $lp.IndexOf('points: [')
$sub = $lp.Substring($i + 7)
$start = $sub.IndexOf('[')
$end = $sub.LastIndexOf(']')
$points = $sub.Substring($start, $end - $start + 1) | ConvertFrom-Json
$centroids = @{}
foreach ($r in $points) {
    # [lng, lat, code, typecode, holder, commodities, expires, hectares, flag]
    $centroids[[string]$r[2]] = $r
}
$geo = Get-Content (Join-Path $root 'data\gov\ngdr\ngdr_active_mining_licenses.geojson') -Raw -Encoding UTF8 | ConvertFrom-Json
$geo.features | ForEach-Object {
    $p = $_.properties
    $c = $centroids[[string]$p.code]
    $flag = if ($c) { [int]$c[8] } else { $null }
    # centroid fallback for features beyond the 5,000-point web layer: mean of first ring vertices
    $fLng = $null; $fLat = $null
    if (-not $c -and $_.geometry -and $_.geometry.coordinates) {
        try {
            $ring = $_.geometry.coordinates[0][0]
            $sx = 0.0; $sy = 0.0; $n = 0
            foreach ($pt in $ring) { $sx += [double]$pt[0]; $sy += [double]$pt[1]; $n++ }
            if ($n -gt 0) { $fLng = [math]::Round($sx / $n, 5); $fLat = [math]::Round($sy / $n, 5) }
        } catch {}
    }
    [pscustomobject]@{
        license_code = $p.code
        license_type = $p.type
        type_code = $p.typecode
        status = $p.status
        holder = $p.parties
        holder_entity_id = Resolve-Entity ($p.parties)
        commodities = if ($c) { $c[5] } else { $null }
        date_applied = $p.dteapplied
        date_granted = $p.dtegranted
        date_expires = $p.dteexpires
        area_hectares = $p.areavalue
        centroid_lng = if ($c) { $c[0] } else { $fLng }
        centroid_lat = if ($c) { $c[1] } else { $fLat }
        centroid_source = if ($c) { 'web_layer' } elseif ($null -ne $fLng) { 'first_ring_mean' } else { $null }
        in_default_notice_2025 = if ($null -ne $flag) { [int](($flag -band 1) -ne 0) } else { $null }
        cancelled_mlc78_2024 = if ($null -ne $flag) { [int](($flag -band 2) -ne 0) } else { $null }
        source = 'NGDR GeoServer open WFS snapshot 2026-07-24 + MMMD notices'
    }
} | Export-Csv (Join-Path $out 'licenses.csv') -NoTypeInformation -Encoding UTF8

# ---------- adverse actions (MMMD) ----------
$adv = @()
$f = Get-Content (Join-Path $root 'data\gov\mmmd_default_notice_2023-10.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$adv += $f | ForEach-Object { [pscustomobject]@{ list='default_notice_2023-10'; action='default notice'; list_date='2023-10';
    license_code=$_.code; holder=$_.holder; holder_entity_id=(Resolve-Entity $_.holder); detail=$null } }
$f = Get-Content (Join-Path $root 'data\gov\mmmd_mlc78_cancellations_2024-04.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$adv += $f | ForEach-Object { [pscustomobject]@{ list='mlc78_cancellations_2024-04'; action='cancellation (MLC 78)'; list_date='2024-04';
    license_code=$_.code; holder=$_.holder; holder_entity_id=(Resolve-Entity $_.holder); detail=$_.comment } }
$f = Get-Content (Join-Path $root 'data\gov\mmmd_default_notice_2025-06-18.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$adv += $f | ForEach-Object { [pscustomobject]@{ list='default_notice_2025-06-18'; action='default notice'; list_date='2025-06-18';
    license_code=$_.code; holder=$_.holder; holder_entity_id=(Resolve-Entity $_.holder); detail=$_.breachSection } }
$adv | Export-Csv (Join-Path $out 'adverse_actions.csv') -NoTypeInformation -Encoding UTF8

# ---------- court cases (ZambiaLII) ----------
$court = Get-Content (Join-Path $root 'data\gov\court\court_hits.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @()
foreach ($prop in $court.names.PSObject.Properties) {
    if ($prop.Value.n -gt 0) {
        foreach ($h in $prop.Value.hits) {
            $cases += [pscustomobject]@{ holder=$prop.Name; holder_entity_id=(Resolve-Entity $prop.Name);
                case_title=$h.t; decision_date=$h.d; court=$h.c; judgment_url=$h.u }
        }
    }
}
$cases | Export-Csv (Join-Path $out 'court_cases.csv') -NoTypeInformation -Encoding UTF8

# ---------- documented disputes (legal_layers.js) ----------
$ll = Get-Content (Join-Path $root 'data\legal_layers.js') -Raw -Encoding UTF8
$i = $ll.IndexOf('cases: [')
$sub = $ll.Substring($i + 7)
$endIdx = $sub.IndexOf("`n  ],")
if ($endIdx -lt 0) { $endIdx = $sub.LastIndexOf(']') } else { $endIdx += 4 }
$json = $sub.Substring(0, $endIdx)
if (-not $json.TrimEnd().EndsWith(']')) { $json = $json.TrimEnd().TrimEnd(',') + ']' }
$json = $json -replace '(?<=[{,]\s*)(name|category|lat|lng|years|summary|source|sourceUrl):', '"$1":'
$json = $json -replace ',(\s*[\]}])', '$1'
($json | ConvertFrom-Json) | ForEach-Object {
    [pscustomobject]@{ dispute=$_.name; category=$_.category; years=$_.years; lat=$_.lat; lng=$_.lng;
        summary=$_.summary; source=$_.source; source_url=$_.sourceUrl }
} | Export-Csv (Join-Path $out 'disputes.csv') -NoTypeInformation -Encoding UTF8

Write-Host "dataset/ written:"
Get-ChildItem $out | ForEach-Object {
    $n = (Import-Csv $_.FullName).Count
    Write-Host ("  {0,-32} {1,6} rows" -f $_.Name, $n)
}
