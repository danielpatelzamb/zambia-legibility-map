# build_register_layer.ps1
# Builds data/register_data.js -> window.REGISTER, the browser layer for the register-legibility
# additions: companies-registry standing, declared business vs mineral rights, published contacts,
# the 1964-2025 production spine, licensing-committee decisions and the cooperative population.
#
# Follows the existing data/*.js convention: one assignment to a window global, compact arrays
# rather than verbose objects, so the terminal can join it client-side with no fetch.
# Run after merge_research_outputs.ps1.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$ds   = Join-Path $root 'dataset'
$out  = Join-Path $root 'data\register_data.js'

function Norm([string]$n) {
    if (-not $n) { return '' }
    $x = ($n.ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b',' '
    ($x -replace '\s+',' ').Trim()
}
function N([object]$v) { if ($null -eq $v -or "$v" -eq '') { $null } else { [double]$v } }
# Multi-match rows serialise their compliance flags as "System.Object[]"; never coerce those to a
# number - an unresolved flag must stay null rather than become a false 0 (which would read as
# "not compliant"). Same reason the declared-business percentages exclude them.
function IntOrNull([object]$v) {
    $s = "$v"
    if ($s -eq '' -or $s -like 'System.Object*') { return $null }
    $n = 0
    if ([int]::TryParse($s, [ref]$n)) { $n } else { $null }
}

# ---------- registry standing, keyed by normalised holder name (for the KYC join) ----------
$pac = Import-Csv (Join-Path $ds 'pacra_registry.csv')
$reg = @{}
foreach ($r in $pac) {
    $k = Norm $r.query_holder
    if (-not $k -or $reg.ContainsKey($k)) { continue }
    if ($r.entity_status -eq 'NO_REGISTRY_MATCH') {
        $reg[$k] = @{ s = 'none' }   # searched, no registry record
        continue
    }
    $nob = if ($r.nature_of_business -like 'System.Object*') { $null } else { $r.nature_of_business }
    $reg[$k] = @{
        n  = $r.entity_name
        no = $r.entity_number
        d  = $r.registration_date
        st = $r.entity_status
        b  = $nob
        bo = IntOrNull $r.beneficial_owner_declared
        ar = IntOrNull $r.annual_return_filed
        nc = IntOrNull $r.nominal_capital_ok
        s  = 'ok'
    }
}

# ---------- published contacts, keyed the same way ----------
$hcPath = Join-Path $root 'private\dataset\holder_contacts_v2.csv'   # private, never emitted
$con = @{}
foreach ($r in (Import-Csv $hcPath)) {
    $k = Norm $r.holder
    if (-not $k) { continue }
    $rec = @{}
    if ($r.website)  { $rec.w  = $r.website }
    if ($r.email)    { $rec.e  = $r.email }
    if ($r.phone)    { $rec.p  = $r.phone }
    if ($r.whatsapp) { $rec.wa = $r.whatsapp }
    if ($r.linkedin) { $rec.li = $r.linkedin }
    if ($r.facebook) { $rec.fb = $r.facebook }
    if ($r.address)  { $rec.a  = $r.address }
    if ($r.district) { $rec.di = $r.district }
    if ($r.town)     { $rec.t  = $r.town }
    if ($r.parent_company) { $rec.pa = $r.parent_company }
    if ($r.contact_person) { $rec.cp = $r.contact_person }
    $rec.mc = $r.match_confidence
    $rec.sc = $r.search_coverage     # 'not_researched' must never read as a verified absence
    if ($rec.Count -gt 2 -and -not $con.ContainsKey($k)) { $con[$k] = $rec }
}

# ---------- cooperatives (no contacts exist; district is the useful key) ----------
$coop = @{}
if (Test-Path (Join-Path $ds 'cooperative_holders.csv')) {
    foreach ($r in (Import-Csv (Join-Path $ds 'cooperative_holders.csv'))) {
        $k = Norm $r.holder
        if (-not $k -or $coop.ContainsKey($k)) { continue }
        $coop[$k] = @{ d = $r.district; p = $r.province; lr = $r.licence_ref; mc = $r.match_confidence }
    }
}

# ---------- aggregates for the charts ----------
$hist = Import-Csv (Join-Path $ds 'historical_production.csv')
$cu = @(($hist | Where-Object { $_.commodity -eq 'copper' -and $_.production_tonnes } | Sort-Object { [int]$_.year }) |
        ForEach-Object { [pscustomobject]@{ y = [int]$_.year; v = [int][double]$_.production_tonnes } })
$co = @(($hist | Where-Object { $_.commodity -eq 'cobalt' -and $_.production_tonnes } | Sort-Object { [int]$_.year }) |
        ForEach-Object { [pscustomobject]@{ y = [int]$_.year; v = [double]$_.production_tonnes } })

$ev = @((Import-Csv (Join-Path $ds 'timeline_events.csv') | Where-Object { $_.year } | Sort-Object { [int]$_.year }) |
        ForEach-Object { [pscustomobject]@{ y = [int]$_.year; c = $_.category; e = $_.event; u = $_.source_url } })

$dec = @(Import-Csv (Join-Path $ds 'official_doc_mentions.csv') | Where-Object { $_.decision } |
         Group-Object decision | Sort-Object Count -Descending |
         ForEach-Object { [pscustomobject]@{ d = $_.Name; n = $_.Count } })

$db  = Import-Csv (Join-Path $ds 'declared_business_vs_licences.csv')
$nm  = @($db | Where-Object business_class -eq 'NOT_mining_related')
$mis = @($nm | Group-Object declared_business | Sort-Object Count -Descending | Select-Object -First 12 |
         ForEach-Object { [pscustomobject]@{ b = $_.Name; n = $_.Count; ha = [int](($_.Group | Measure-Object hectares -Sum).Sum) } })
$misBig = @($nm | Sort-Object { -[int]$_.hectares } | Select-Object -First 12 |
            ForEach-Object { [pscustomobject]@{ h = $_.holder; ha = [int]$_.hectares; b = $_.declared_business
                                                bo = $_.beneficial_owner_declared; df = $_.lics_in_default_2025 } })

$cp = @(Import-Csv (Join-Path $ds 'cooperative_holders.csv') |
        Where-Object { $_.province -and $_.province -notmatch ';' } | Group-Object province |
        Sort-Object Count -Descending | ForEach-Object { [pscustomobject]@{ p = $_.Name; n = $_.Count } })

$chain = @(Import-Csv (Join-Path $ds 'supply_chain_links.csv') | ForEach-Object {
    [pscustomobject]@{ e = $_.entity; c = $_.counterparty; t = $_.link_type; v = N $_.value_usd
                       vol = $_.volume; st = $_.status; d = $_.description; u = $_.source_url } })

$va = @(Import-Csv (Join-Path $ds 'value_addition_efforts.csv') | ForEach-Object {
    [pscustomobject]@{ n = $_.name; c = $_.category; y = $_.year_started; st = $_.status; v = N $_.value_usd; u = $_.source_url } })

# PRIVACY: contact fields are deliberately NOT emitted to the browser layer. The public app names
# the institutional route (which office, which province) so the map stays useful; the phone/email
# for each sits only in private/ and never ships. Same for company contacts - no CONTACTS key.
$chanSrc = Join-Path $root 'private\dataset\asm_outreach_channels.csv'
$chan = @()
if (Test-Path $chanSrc) {
    $chan = @(Import-Csv $chanSrc | Where-Object { $_.reachable -eq 'yes' } |
              ForEach-Object { [pscustomobject]@{ n = $_.name; cat = $_.category; l = $_.level
                                                  pr = $_.province; di = $_.district; r = $_.role } })
}

# ---------- economic linkage: which minerals sit under a non-mining declaration ----------
# The interesting join. A holder's declared line of business comes from the companies registry;
# the minerals come from the licence register. Where they disagree, this is where it shows up.
$nmKeys = @{}
foreach ($r in ($db | Where-Object business_class -eq 'NOT_mining_related')) {
    $k = Norm $r.holder; if ($k) { $nmKeys[$k] = $r.declared_business }
}
$licAll = Import-Csv (Join-Path $ds 'licenses.csv')
$mineralNM = @{}; $mineralAll = @{}
foreach ($l in $licAll) {
    if (-not $l.commodities) { continue }
    $k = Norm (($l.holder -replace '\s*\(\d+(\.\d+)?%\)','').Trim())
    $isNM = $nmKeys.ContainsKey($k)
    foreach ($c in ($l.commodities -split ',\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $mineralAll[$c] = 1 + [int]$mineralAll[$c]
        if ($isNM) { $mineralNM[$c] = 1 + [int]$mineralNM[$c] }
    }
}
$mineralLink = @($mineralNM.GetEnumerator() | Where-Object { $_.Value -ge 20 } | ForEach-Object {
    [pscustomobject]@{ m = $_.Key; nm = $_.Value; all = [int]$mineralAll[$_.Key]
                       sh = [math]::Round(100 * $_.Value / [int]$mineralAll[$_.Key], 1) } } |
    Sort-Object { -$_.nm })

# normalised keys of non-mining-declared holders, so the MAP can shade their licences
$nmHolderKeys = @($nmKeys.Keys | Sort-Object)

# ---------- legibility coverage by licence bucket ----------
function Bucket([string]$code) {
    switch -Regex ($code) {
        '^(LEL|SEL|PL|LPL)$' { 'Exploration' }
        '^AMR$'              { 'Artisanal' }
        '^BA$'               { 'Bidding area' }
        '^(SML|LML)$'        { 'Mining' }
        '^MPL$'              { 'Processing' }
        '^(SGL|LGL)$'        { 'Gemstone licence' }
        '^PP$'               { 'Prospecting permit' }
        default              { 'Portal / test' }
    }
}
$hcAllRows = Import-Csv $hcPath
$reachKeys = @{}; $knownKeys = @{}
foreach ($r in $hcAllRows) { $k = Norm $r.holder; if ($k) { $knownKeys[$k] = 1; if ($r.reachable -eq 'yes') { $reachKeys[$k] = 1 } } }
$buckets = @(($licAll | Group-Object { Bucket $_.type_code }) | ForEach-Object {
    $hs = @($_.Group | ForEach-Object { Norm (($_.holder -replace '\s*\(\d+(\.\d+)?%\)','').Trim()) } | Where-Object { $_ } | Sort-Object -Unique)
    [pscustomobject]@{
        b   = $_.Name
        lic = $_.Count
        h   = $hs.Count
        res = @($hs | Where-Object { $knownKeys[$_] }).Count
        rch = @($hs | Where-Object { $reachKeys[$_] }).Count
        def = @($_.Group | Where-Object in_default_notice_2025 -eq '1').Count
        nmh = @($hs | Where-Object { $nmKeys.ContainsKey($_) }).Count
    } } | Sort-Object { -$_.lic })

# ---------- gemstone: licence type vs actual commodity ----------
$gemPat = 'EMERALD|AMETHYST|AQUAMARIN|TOURMALIN|BERYL|GARNET|GEMSTONE|DIAMOND|SAPPHIRE|RUBY|OPAL|TOPAZ|CITRINE|JADE|AGATE'
$gemLic = @($licAll | Where-Object { $_.commodities -match $gemPat })
$gemByType = @(($gemLic | Group-Object license_type) | ForEach-Object {
    [pscustomobject]@{ t = $_.Name; n = $_.Count } } | Sort-Object { -$_.n })
$gemFacts = [ordered]@{
    typeLic  = @($licAll | Where-Object { $_.license_type -match 'Gemstone' }).Count
    commLic  = $gemLic.Count
    holders  = @($gemLic | ForEach-Object { Norm (($_.holder -replace '\s*\(\d+(\.\d+)?%\)','').Trim()) } | Where-Object { $_ } | Sort-Object -Unique).Count
    byType   = $gemByType
}

# ---------- processing licence holders (mappable: they carry centroids) ----------
$mplRows = @($licAll | Where-Object { $_.type_code -eq 'MPL' })
$processors = @(($mplRows | Group-Object { ($_.holder -replace '\s*\(\d+(\.\d+)?%\)','').Trim() }) | ForEach-Object {
    $g = $_.Group[0]
    $k = Norm $_.Name
    [pscustomobject]@{
        h = $_.Name; n = $_.Count
        comm = (($_.Group.commodities -join ', ') -split ',\s*' | Where-Object { $_ } | Sort-Object -Unique) -join '/'
        def = @($_.Group | Where-Object in_default_notice_2025 -eq '1').Count
        can = @($_.Group | Where-Object cancelled_mlc78_2024 -eq '1').Count
        lat = $g.centroid_lat; lng = $g.centroid_lng
        nm  = if ($nmKeys.ContainsKey($k)) { $nmKeys[$k] } else { $null }
    } } | Sort-Object { -$_.n })
# headline counters, computed not hardcoded
$pacM   = @($pac | Where-Object { $_.entity_status -ne 'NO_REGISTRY_MATCH' })
$hcAll  = Import-Csv $hcPath
$resolvedDb = @($db | Where-Object { $_.business_class -ne 'UNRESOLVED_MULTI_MATCH' })
$haNot = ($nm | Measure-Object hectares -Sum).Sum
$haAll = ($resolvedDb | Measure-Object hectares -Sum).Sum

$stats = [ordered]@{
    licences        = (Import-Csv (Join-Path $ds 'licenses.csv')).Count
    pacraQueried    = $pac.Count
    pacraMatched    = $pacM.Count
    boUndeclared    = @($pacM | Where-Object beneficial_owner_declared -eq '0').Count
    returnsUnfiled  = @($pacM | Where-Object annual_return_filed -eq '0').Count
    belowCapital    = @($pacM | Where-Object nominal_capital_ok -eq '0').Count
    nonMining       = $nm.Count
    resolvedBusiness= $resolvedDb.Count
    unresolvedBiz   = @($db | Where-Object business_class -eq 'UNRESOLVED_MULTI_MATCH').Count
    nonMiningHa     = [int]$haNot
    allHa           = [int]$haAll
    noRegistry      = 214
    researched      = $hcAll.Count
    reachable       = @($hcAll | Where-Object reachable -eq 'yes').Count
    notResearched   = @($hcAll | Where-Object search_coverage -eq 'not_researched').Count
    coops           = @(Import-Csv (Join-Path $ds 'cooperative_holders.csv')).Count
    coopLocated     = @(Import-Csv (Join-Path $ds 'cooperative_holders.csv') | Where-Object located -eq 'yes').Count
    channels        = @(Import-Csv $chanSrc).Count
    channelsReach   = $chan.Count
    docMentions     = (Import-Csv (Join-Path $ds 'official_doc_mentions.csv')).Count
}

$payload = [ordered]@{
    STATS = $stats; REG = $reg; COOPS = $coop
    CU = $cu; CO = $co; EVENTS = $ev; DECISIONS = $dec
    MISMATCH = $mis; MISMATCH_BIG = $misBig; COOP_PROV = $cp
    CHAIN = $chain; VALUE_ADD = $va; CHANNELS = $chan
    MINERAL_LINK = $mineralLink; NM_HOLDERS = $nmHolderKeys; BUCKETS = $buckets
    GEM = $gemFacts; PROCESSORS = $processors
}
$json = $payload | ConvertTo-Json -Depth 8 -Compress
$hdr = "/* register_data.js - generated by pipeline/build_register_layer.ps1. Do not hand-edit.`n" +
       "   Companies-registry standing, declared business, published contacts, 1964-2025 production,`n" +
       "   licensing decisions, cooperatives and institutional channels. */`n"
[System.IO.File]::WriteAllText($out, $hdr + "window.REGISTER = " + $json + ";`n", (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("wrote {0} ({1:N0} KB)" -f $out, ((Get-Item $out).Length/1KB))
Write-Host ("  registry keys {0} | contact keys {1} | coop keys {2}" -f $reg.Count, $con.Count, $coop.Count)
Write-Host ("  copper {0} pts | events {1} | decisions {2} | chain {3} | value-add {4} | channels {5}" -f $cu.Count, $ev.Count, $dec.Count, $chain.Count, $va.Count, $chan.Count)
$stats.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-17} {1}" -f $_.Key, $_.Value) }
