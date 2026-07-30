# merge_research_outputs.ps1
# Folds research-agent outputs (research/*.json) into dataset/ CSVs and builds the
# entity-year analysis panel. Run after build_analysis_dataset.ps1.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$res  = Join-Path $root 'research'
$out  = Join-Path $root 'dataset'

# entity resolution from the crosswalk written by build_analysis_dataset.ps1
function Normalize-Name([string]$n) {
    if (-not $n) { return '' }
    ($n -replace '\(100%\)', '' -replace '\s+', ' ').Trim().ToUpperInvariant()
}
$variantMap = @{}
foreach ($e in (Import-Csv (Join-Path $out 'entities.csv'))) {
    $variantMap[(Normalize-Name $e.canonical_name)] = $e.entity_id
    foreach ($v in ($e.name_variants -split '\|')) { if ($v) { $variantMap[(Normalize-Name $v)] = $e.entity_id } }
}
# loose aliases agents are likely to use
$aliases = @{
    'FIRST QUANTUM MINERALS' = 'KANSANSHI'  # only when Zambian asset unspecified; keep explicit ones below
    'FQM TRIDENT LTD' = 'FQM_TRIDENT'; 'SENTINEL' = 'FQM_TRIDENT'; 'SENTINEL MINE' = 'FQM_TRIDENT'
    'KALUMBILA MINERALS LTD' = 'FQM_TRIDENT'
    'KONKOLA COPPER MINES PLC (KCM)' = 'KCM'; 'KCM' = 'KCM'
    'MOPANI COPPER MINES' = 'MOPANI'
    'CHAMBISHI COPPER SMELTER' = 'CCS'; 'CHAMBISHI COPPER SMELTER LTD' = 'CCS'
    'CNMC LUANSHYA' = 'CNMC_LUANSHYA'
    'NFC AFRICA MINING' = 'NFCA'; 'NFC AFRICA' = 'NFCA'
    'SINO-METALS LEACH ZAMBIA LTD' = 'SINO_METALS'; 'SINO-METALS' = 'SINO_METALS'
    'LUMWANA MINING CO LTD' = 'LUMWANA'; 'LUMWANA MINING COMPANY' = 'LUMWANA'
    'LUBAMBE COPPER MINE LTD' = 'LUBAMBE'; 'LUBAMBE COPPER MINE' = 'LUBAMBE'
    'CHIBULUMA MINES' = 'CHIBULUMA'
    'MIMBULA MINERALS LTD' = 'MIMBULA'; 'MIMBULA' = 'MIMBULA'
    'ZCCM INVESTMENTS HOLDINGS' = 'ZCCM_IH'; 'ZCCM-IH' = 'ZCCM_IH'
    'METAL FABRICATORS OF ZAMBIA' = 'ZAMEFA'; 'ZAMEFA' = 'ZAMEFA'
    'METAL FABRICATORS OF ZAMBIA PLC (ZAMEFA)' = 'ZAMEFA'
}
foreach ($k in $aliases.Keys) { if (-not $variantMap.ContainsKey($k)) { $variantMap[$k] = $aliases[$k] } }
function Resolve-Entity([string]$raw) {
    $n = Normalize-Name $raw
    if ($variantMap.ContainsKey($n)) { return $variantMap[$n] }
    $n2 = ($n -replace '\b(LIMITED|LTD|PLC)\b', '').Trim() -replace '\s+', ' '
    foreach ($k in $variantMap.Keys) {
        $k2 = ($k -replace '\b(LIMITED|LTD|PLC)\b', '').Trim() -replace '\s+', ' '
        if ($k2 -and $k2 -eq $n2) { return $variantMap[$k] }
    }
    $null
}
function Load-Json([string]$name) {
    $p = Join-Path $res $name
    if (Test-Path $p) { Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json } else { Write-Warning "missing $name"; @() }
}

# ---------- contacts ----------
$contacts = Load-Json 'entity_contacts.json'
if ($contacts) {
    $contacts | ForEach-Object {
        [pscustomobject]@{
            entity_id = Resolve-Entity $_.entity
            entity = $_.entity
            entity_type = $_.type
            website = $_.website
            hq_address_zambia = $_.hq_address_zambia
            phone = $_.phone
            email = $_.email
            parent_company = $_.parent_company
            parent_hq = $_.parent_hq
            ownership_notes = $_.ownership_notes
            officers = if ($_.officers) { ($_.officers | ForEach-Object { "$($_.name) ($($_.title))" }) -join '; ' } else { $null }
            ticker = $_.ticker
            linkedin = $_.linkedin
            whatsapp = $_.whatsapp
            other_channels = if ($_.other_channels) { @($_.other_channels) -join ' | ' } else { $null }
            facility_contacts = if ($_.facility_contacts) {
                ($_.facility_contacts | ForEach-Object {
                    (@($_.facility, $_.phone, $_.email, $_.address) | Where-Object { $_ }) -join ', '
                }) -join ' || '
            } else { $null }
            sources = if ($_.sources) { $_.sources -join ' | ' } else { $null }
        }
    } | Export-Csv (Join-Path $out 'entity_contacts.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- facilities ----------
$fac = Load-Json 'facilities.json'
if ($fac) {
    $fac | ForEach-Object {
        [pscustomobject]@{
            facility = $_.name
            operator = $_.operator
            operator_entity_id = Resolve-Entity $_.operator
            facility_type = $_.type
            products = $_.products
            latitude = $_.latitude
            longitude = $_.longitude
            coordinate_source = $_.coordinate_source
            town = $_.town
            status = $_.status
            capacity = $_.capacity
            sources = if ($_.sources) { ($_.sources -join ' | ') } else { $_.source }
        }
    } | Export-Csv (Join-Path $out 'facilities.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- bill of lading shipments ----------
$bol = Load-Json 'bol_shipments.json'
if ($bol) {
    $bol | ForEach-Object {
        [pscustomobject]@{
            source = $_.source; date = $_.date
            shipper = $_.shipper; shipper_entity_id = Resolve-Entity $_.shipper
            consignee = $_.consignee
            product = $_.product; hs_code = $_.hs_code
            weight_kg = $_.weight_kg; value_usd = $_.value_usd
            origin = $_.origin; destination = $_.destination; url = $_.url
        }
    } | Export-Csv (Join-Path $out 'bol_shipments.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- top license-holder contacts (batched research) ----------
# note: ConvertFrom-Json emits a JSON array as ONE Object[] item; pipe through
# ForEach-Object to enumerate, otherwise each batch lands as a single element
$hc = @(foreach ($b in 1..24) { Load-Json "holder_contacts_batch$b.json" | ForEach-Object { $_ } })
# value-chain stratified batches (segment-aware schema, adds facebook/district/contact_person)
$hc += @(foreach ($b in 'A','B','C','D','E','F','G','H','I') { Load-Json "vc_contacts_batch$b.json" | ForEach-Object { $_ } })
if ($hc) {
    $hc | ForEach-Object {
        # CRITICAL data-integrity distinction: a null contact can mean either "searched and
        # found nothing" or "never actually looked up" (search budget exhausted / CAPTCHA wall
        # during the 2026-07-28 sweep). Agents recorded that in prose; surface it as a column
        # so nulls are never misread as verified absences.
        $cov = if ($_.notes -match 'NOT RESEARCHED') { 'not_researched' }
               elseif ($_.notes -match 'COVERAGE CAVEAT') { 'partial_search_only' }
               else { 'searched' }
        [pscustomobject]@{
            holder = $_.holder
            holder_entity_id = Resolve-Entity $_.holder
            # normalized key: the register records some companies under several name variants,
            # each variant holding different licences. Group on this before per-holder counting.
            holder_key = (((($_.holder).ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b',' ') -replace '\s+',' ').Trim()
            segment = $_.segment
            match_confidence = $_.match_confidence
            search_coverage = $cov
            website = $_.website; email = $_.email; phone = $_.phone
            whatsapp = $_.whatsapp; linkedin = $_.linkedin; facebook = $_.facebook
            address = $_.address; town = $_.town; district = $_.district
            parent_company = $_.parent_company; contact_person = $_.contact_person
            # is there any channel you could actually reach them on?
            reachable = if ($_.phone -or $_.email -or $_.website -or $_.whatsapp -or $_.linkedin -or $_.facebook) { 'yes' } else { 'no' }
            notes = $_.notes
            sources = if ($_.sources) { $_.sources -join ' | ' } else { $null }
        }
    } | Sort-Object holder | Export-Csv (Join-Path $out 'holder_contacts.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- official-document holder mentions (MMMD licensing minutes, default/cancellation notices, ZEMA) ----------
# ~16k mentions mined from 60 official documents; resolves district/province/licence area/decision
# for the large majority of the register. Sentinel note-records are excluded from the CSV.
$od = Load-Json 'official_docs_holders.json'
if ($od) {
    $od | Where-Object { $_.holder -and $_.holder -notmatch 'NEEDS_LOCAL_EXTRACTION|^NOTE' } | ForEach-Object {
        [pscustomobject]@{
            holder = $_.holder
            holder_entity_id = Resolve-Entity $_.holder
            license_code = $_.license_code
            area_hectares = $_.area_hectares
            district = $_.district; province = $_.province
            commodities = $_.commodities; decision = $_.decision
            source_doc = $_.source_doc; doc_date = $_.doc_date; source_url = $_.source_url
            address = $_.address; phone = $_.phone; email = $_.email; contact_person = $_.contact_person
            notes = $_.notes
        }
    } | Sort-Object holder, doc_date | Export-Csv (Join-Path $out 'official_doc_mentions.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- PACRA registry status (public API: registration, compliance, beneficial-ownership) ----------
$pac = Load-Json 'pacra_registry.json'
if ($pac) {
    $pac | ForEach-Object {
        [pscustomobject]@{
            query_holder = $_.query_holder; segment = $_.segment
            entity_name = $_.entity_name; entity_number = $_.entity_number
            registration_date = $_.registration_date; nature_of_business = $_.nature_of_business
            entity_status = $_.entity_status; company_type = $_.company_type
            isic_classification = $_.isic_classification
            exact_name_match = $_.exact_name_match
            annual_return_filed = $_.annual_return_status
            # 0 = beneficial ownership NOT declared (statutory non-compliance); 1 = declared
            beneficial_owner_declared = $_.beneficial_owner_status
            nominal_capital_ok = $_.nominal_capital_status
            annual_return_reason = $_.annual_return_reason
            beneficial_owner_reason = $_.beneficial_owner_reason
            nominal_capital_reason = $_.nominal_capital_reason
        }
    } | Sort-Object query_holder, entity_name | Export-Csv (Join-Path $out 'pacra_registry.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- segmented sector directory (gemstones / ASM associations / manufacturers / traders / services) ----------
$sec = Load-Json 'sector_directory.json'
if ($sec) {
    $sec | ForEach-Object {
        [pscustomobject]@{
            segment = $_.segment; name = $_.name; role = $_.role
            entity_id = Resolve-Entity $_.name
            website = $_.website; phone = $_.phone; email = $_.email
            whatsapp = $_.whatsapp; linkedin = $_.linkedin
            address = $_.address; town = $_.town; notes = $_.notes
            sources = if ($_.sources) { $_.sources -join ' | ' } else { $null }
        }
    } | Sort-Object segment, name | Export-Csv (Join-Path $out 'sector_directory.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- value-addition efforts (policy / zones / initiatives / projects / state vehicles) ----------
$va = Load-Json 'value_addition_efforts.json'
if ($va) {
    $va | ForEach-Object {
        [pscustomobject]@{
            category = $_.category; name = $_.name
            year_started = $_.year_started; status = $_.status
            description = $_.description; value_usd = $_.value_usd
            entities = if ($_.entities) { @($_.entities) -join ' | ' } else { $null }
            entity_ids = if ($_.entities) { (@($_.entities) | ForEach-Object { Resolve-Entity $_ } | Where-Object { $_ } | Sort-Object -Unique) -join ' | ' } else { $null }
            source_name = $_.source_name; source_url = $_.source_url; note = $_.note
        }
    } | Sort-Object category, year_started | Export-Csv (Join-Path $out 'value_addition_efforts.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- supply-chain links (offtakes, streams, corridors, logistics) ----------
$scl = Load-Json 'supply_chain_links.json'
if ($scl) {
    $scl | ForEach-Object {
        [pscustomobject]@{
            entity = $_.entity; entity_id = Resolve-Entity $_.entity
            counterparty = $_.counterparty
            link_type = $_.link_type; commodity = $_.commodity
            value_usd = $_.value_usd; volume = $_.volume; period = $_.period
            status = $_.status; description = $_.description
            source_name = $_.source_name; source_url = $_.source_url
        }
    } | Sort-Object entity, link_type | Export-Csv (Join-Path $out 'supply_chain_links.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- cooperative licence holders (229 societies that register outside PACRA) ----------
# Verified across 140 societies by two independent agents: NO cooperative in this population
# publishes an office phone, email or address anywhere. They sit outside the companies registry,
# their artisanal rights fall below ZEMA's EIA threshold so they never file an EIS, and most have
# no web footprint at all. What IS recoverable is district/province/licence code from MMMD
# Mining Licensing Committee notices. Route to this population is ZFCM (see asm_outreach_channels).
$coop = @(foreach ($b in 1..6) { Load-Json "coop_contacts_batch$b.json" | ForEach-Object { $_ } })
if ($coop) {
    $coop | ForEach-Object {
        [pscustomobject]@{
            holder = $_.holder
            match_confidence = $_.match_confidence
            district = $_.district; province = $_.province; town = $_.town
            licence_ref = $_.registrar_reference
            office_phone = $_.office_phone; office_email = $_.office_email
            postal_address = $_.postal_address; physical_address = $_.physical_address
            officeholder = $_.officeholder; parent_union = $_.parent_union; facebook = $_.facebook
            located = if ($_.district -or $_.province) { 'yes' } else { 'no' }
            reachable = if ($_.office_phone -or $_.office_email) { 'yes' } else { 'no' }
            notes = $_.notes
            sources = if ($_.sources) { @($_.sources) -join ' | ' } else { $null }
        }
    } | Sort-Object holder | Export-Csv (Join-Path $out 'cooperative_holders.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- ASM / institutional outreach channels (gatekeepers for the 902 individual holders) ----------
$asm = Load-Json 'asm_outreach_channels.json'
if ($asm) {
    $asm | ForEach-Object {
        [pscustomobject]@{
            category = $_.category; name = $_.name; level = $_.level
            province = $_.province; district = $_.district; role = $_.role
            website = $_.website; email = $_.email; phone = $_.phone
            address = $_.address; officeholder = $_.officeholder
            reachable = if ($_.email -or $_.phone) { 'yes' } else { 'no' }
            notes = $_.notes
            sources = if ($_.sources) { @($_.sources) -join ' | ' } else { $null }
        }
    } | Sort-Object category, level, name | Export-Csv (Join-Path $out 'asm_outreach_channels.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- contacts recovered from novel sources (Companies House, exhibitor lists, chamber directories) ----------
$nsc = Load-Json 'novel_source_contacts.json'
if ($nsc) {
    $nsc | ForEach-Object {
        [pscustomobject]@{
            holder = $_.holder; holder_entity_id = Resolve-Entity $_.holder
            source_type = $_.source_type; source_name = $_.source_name; source_url = $_.source_url
            website = $_.website; email = $_.email; phone = $_.phone; address = $_.address
            officeholder = $_.officeholder; company_number = $_.company_number
            parent_company = $_.parent_company; confidence = $_.confidence; notes = $_.notes
        }
    } | Sort-Object source_type, holder | Export-Csv (Join-Path $out 'novel_source_contacts.csv') -NoTypeInformation -Encoding UTF8
}
# NOTE: research/novel_probe_results.json is deliberately NOT merged. Its MX/inferred-email
# results were verified as FALSE POSITIVES — the domain-stem generator matched first words to
# unrelated global companies (Abar International -> abar.com, Achilles Mining -> achilles.com)
# and to parked domains with null MX. Merging it would fabricate contacts for the wrong firms.

# ---------- price series ----------
$prices = Load-Json 'price_series.json'
if ($prices) {
    $prices | ForEach-Object {
        [pscustomobject]@{ commodity=$_.commodity; year=$_.year; avg_price=$_.avg_price; unit=$_.unit;
            source_name=$_.source_name; source_url=$_.source_url }
    } | Export-Csv (Join-Path $out 'price_series.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- historical production series (1964+) ----------
$hist = Load-Json 'historical_production.json'
if ($hist) {
    $hist | ForEach-Object {
        [pscustomobject]@{ commodity=$_.commodity; year=$_.year; production_tonnes=$_.production_tonnes;
            unit=$_.unit; source_name=$_.source_name; source_url=$_.source_url }
    } | Sort-Object commodity, year | Export-Csv (Join-Path $out 'historical_production.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- structural events timeline (1964+) ----------
$tl = Load-Json 'timeline_events.json'
if ($tl) {
    $tl | ForEach-Object {
        [pscustomobject]@{ year=$_.year; date=$_.date; event=$_.event; category=$_.category
            entities = if ($_.entities) { @($_.entities) -join ' | ' } else { $null }
            entity_ids = if ($_.entities) { (@($_.entities) | ForEach-Object { Resolve-Entity $_ } | Where-Object { $_ } | Sort-Object -Unique) -join ' | ' } else { $null }
            source_name=$_.source_name; source_url=$_.source_url }
    } | Sort-Object year, date | Export-Csv (Join-Path $out 'timeline_events.csv') -NoTypeInformation -Encoding UTF8
}

# ---------- unified entity values (ZEITI + agent-collected) ----------
$vals = @()
$zeiti = Join-Path $out 'entity_values_zeiti.csv'
if (Test-Path $zeiti) {
    $vals += Import-Csv $zeiti | ForEach-Object {
        [pscustomobject]@{ entity_id=$_.entity_id; entity=$_.entity_as_published; facility=$null; year=$_.year;
            metric=$_.metric; value=$_.value; unit=$_.unit; as_of_date=$null; source_name=$_.source; source_url=$null; note=$null }
    }
}
foreach ($file in @('entity_values.json','valuations.json','fabrication_financials.json')) {
    $j = Load-Json $file
    if ($j) {
        $vals += $j | ForEach-Object {
            [pscustomobject]@{ entity_id=(Resolve-Entity $_.entity); entity=$_.entity; facility=$_.facility; year=$_.year;
                metric=$_.metric; value=$_.value; unit=$_.unit; as_of_date=$_.as_of_date;
                source_name=$_.source_name; source_url=$_.source_url; note=$_.note }
        }
    }
}
$vals | Export-Csv (Join-Path $out 'entity_values.csv') -NoTypeInformation -Encoding UTF8

# ---------- entity-year analysis panel ----------
# One row per entity-year: production tonnes (EITI), reported USD values, implied gross value
# (tonnes x World Bank avg copper price), adverse/court counts.
$prod = Import-Csv (Join-Path $out 'entity_production.csv') | Where-Object { $_.entity_id -and $_.commodity -eq 'Copper' }
$cuPrice = @{}
if ($prices) { $prices | Where-Object { $_.commodity -match 'opper' } | ForEach-Object { $cuPrice[[string]$_.year] = [double]$_.avg_price } }
$advCount = @{}
Import-Csv (Join-Path $out 'adverse_actions.csv') | Where-Object { $_.holder_entity_id } | ForEach-Object {
    $advCount[$_.holder_entity_id] = 1 + [int]$advCount[$_.holder_entity_id] }
$courtCount = @{}
Import-Csv (Join-Path $out 'court_cases.csv') | Where-Object { $_.holder_entity_id } | ForEach-Object {
    $courtCount[$_.holder_entity_id] = 1 + [int]$courtCount[$_.holder_entity_id] }
$valLookup = @{}
foreach ($v in $vals) { if ($v.entity_id -and $v.year) { $valLookup["$($v.entity_id)|$($v.year)|$($v.metric)"] = $v.value } }

$prod | Group-Object entity_id, year | ForEach-Object {
    $r = $_.Group[0]
    $t = ($_.Group | Measure-Object -Property volume -Sum).Sum
    $py = $cuPrice[[string]$r.year]
    [pscustomobject]@{
        entity_id = $r.entity_id
        year = $r.year
        copper_production_tonnes = $t
        reported_production_value_usd = $valLookup["$($r.entity_id)|$($r.year)|production_value_usd"]
        reported_revenue_usd = $valLookup["$($r.entity_id)|$($r.year)|revenue_usd"]
        payments_to_govt_usd = $valLookup["$($r.entity_id)|$($r.year)|payments_to_govt_usd"]
        wb_avg_cu_price_usd_t = $py
        implied_gross_value_usd = if ($py) { [math]::Round($t * $py, 0) } else { $null }
        adverse_action_count_alltime = [int]$advCount[$r.entity_id]
        court_case_count_alltime = [int]$courtCount[$r.entity_id]
    }
} | Sort-Object entity_id, year | Export-Csv (Join-Path $out 'entity_year_panel.csv') -NoTypeInformation -Encoding UTF8

Write-Host "merged. dataset/ now:"
Get-ChildItem $out -Filter *.csv | ForEach-Object {
    $n = (Import-Csv $_.FullName).Count
    Write-Host ("  {0,-32} {1,6} rows" -f $_.Name, $n)
}
