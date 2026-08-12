# build_origin_gate_api.ps1
# Generates a static, callable Origin Gate API under api/v1/.
#
# WHY STATIC: the site is GitHub Pages, so there is no server to run. Pre-generating one JSON
# file per licence code gives a real HTTP contract (GET a URL, get a typed answer) with no
# hosting cost, no downtime and no rate limit. GitHub Pages sends
# Access-Control-Allow-Origin: * on these, so a browser or an off-chain worker can call it
# cross-origin without a proxy.
#
# THE GATE: `verified` is TRUE only when all four public checks pass. It is deliberately a
# BINARY gate rather than a rich provenance payload. Rich per-lot provenance fragments a
# fungible commodity into thousands of non-interchangeable lots and destroys price discovery;
# a binary gate concentrates liquidity into one pool, which is how LME brand approval has
# worked for a century. Check detail is still returned, for audit rather than for trading.
#
# Endpoints written:
#   api/v1/index.json                  service metadata, counts, source provenance
#   api/v1/openapi.json                OpenAPI 3.1 description of the contract
#   api/v1/licence/<CODE>.json         the gate response for one licence code
#   api/v1/bulk/gate.json              every code with its verdict, for bulk consumers
#
# Codes NOT on the active register but named in an adverse notice still get a file, reporting
# revoked rather than unknown. A 404 cannot distinguish those two, and the difference is the
# entire point of the gate.
#
# PERFORMANCE NOTE: the per-record JSON is written by hand rather than through ConvertTo-Json.
# ConvertTo-Json across ~13,000 records does not finish in a reasonable time on PS 5.1. Hand
# serialising is also deterministic, so re-running on unchanged data produces an empty diff.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$u = New-Object System.Text.UTF8Encoding($false)
$apiRoot = Join-Path $root 'api\v1'
$SCHEMA = 'zm-origin-gate/v1'
$BASE = 'https://danielpatelzamb.github.io/zambia-legibility-map/api/v1'
# Snapshot date of the underlying registers, fixed rather than read from the clock so a rebuild
# of unchanged data produces byte-identical output.
$GENERATED = '2026-08-12'

# ---------- JSON helpers ----------
function J([string]$s) {
    if ($null -eq $s) { return 'null' }
    $b = New-Object System.Text.StringBuilder
    [void]$b.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        switch ($ch) {
            '"'  { [void]$b.Append('\"') }
            '\'  { [void]$b.Append('\\') }
            "`n" { [void]$b.Append('\n') }
            "`r" { [void]$b.Append('\r') }
            "`t" { [void]$b.Append('\t') }
            default {
                if ([int]$ch -lt 32) { [void]$b.Append('\u{0:x4}' -f [int]$ch) }
                else { [void]$b.Append($ch) }
            }
        }
    }
    [void]$b.Append('"')
    $b.ToString()
}
function B([bool]$v) { if ($v) { 'true' } else { 'false' } }
function JN($v) { if ($null -eq $v -or "$v" -eq '') { 'null' } else { J "$v" } }

# ---------- load the data layers ----------
function Load-Json([string]$file, [string]$global) {
    $t = [IO.File]::ReadAllText((Join-Path $root "data\$file"), $u)
    $i = $t.IndexOf("window.$global")
    if ($i -lt 0) { throw "no window.$global in $file" }
    $s = $t.Substring($t.IndexOf('=', $i) + 1).Trim()
    if ($s.EndsWith(';')) { $s = $s.Substring(0, $s.Length - 1) }
    $s | ConvertFrom-Json
}
$LIC = Load-Json 'licenses_points.js' 'LICENSES'
# The registry arrives as a PSCustomObject keyed by normalised holder name. Flatten it into a
# hashtable: PSObject.Properties cannot be indexed by name, and this is looked up 7,444 times.
# Named $REGISTRY, not $REG: PowerShell variables are case-INSENSITIVE, so a table called $REG
# is silently destroyed by the per-row $reg on the first loop iteration. That cost a debug pass.
$REGISTRY = @{}
foreach ($prop in (Load-Json 'register_data.js' 'REGISTER').REG.PSObject.Properties) {
    $REGISTRY[$prop.Name] = $prop.Value
}
Write-Host ("loaded {0} licence points, {1} registry records" -f $LIC.points.Count, $REGISTRY.Count)

# kyc_data.js is JavaScript, not JSON: its object keys are unquoted, so ConvertFrom-Json
# refuses it. The row format is rigid, so parse it line by line instead.
$kycText = [IO.File]::ReadAllText((Join-Path $root 'data\kyc_data.js'), $u)
$ADVERSE = @{}
$listLabels = @{}
$curKey = $null
foreach ($line in ($kycText -split "`n")) {
    $m = [regex]::Match($line, '^\s*"([A-Za-z0-9_]+)"\s*:\s*\{\s*label:\s*"([^"]*)"')
    if ($m.Success) { $curKey = $m.Groups[1].Value; $listLabels[$curKey] = $m.Groups[2].Value; continue }
    if (-not $curKey) { continue }
    $r = [regex]::Match($line, '^\s*\["([^"]*)","([^"]*)","?([^"\]]*)"?\]')
    if (-not $r.Success) { continue }
    $code = $r.Groups[1].Value.ToUpper().Trim()
    if (-not $code) { continue }
    if (-not $ADVERSE.ContainsKey($code)) { $ADVERSE[$code] = New-Object System.Collections.Generic.List[object] }
    $ADVERSE[$code].Add([pscustomobject]@{
        notice = $listLabels[$curKey]; list_id = $curKey
        holder_as_listed = $r.Groups[2].Value; detail = $r.Groups[3].Value
    })
}
Write-Host ("parsed {0} adverse lists covering {1} distinct licence codes" -f $listLabels.Count, $ADVERSE.Count)

# ---------- reference tables ----------
$TYPE_NAME = @{
    LEL='Large-scale exploration licence'; SEL='Small-scale exploration licence'
    LML='Large-scale mining licence'; SML='Small-scale mining licence'
    AMR='Artisanal mining right'; MPL='Mineral processing licence'
    LGL='Large-scale gemstone licence'; SGL='Small-scale gemstone licence'
    BA='Gazetted bidding area'; PL='Prospecting licence'; PP='Prospecting permit'
    LPL='Large-scale prospecting licence'
    P_LEL='Pending large-scale exploration'; P_LML='Pending large-scale mining'
    P_SML='Pending small-scale mining'; P_MPL='Pending mineral processing'
}
# Only these classes can lawfully be the origin of minerals offered for sale. An exploration or
# bidding-area right cannot, and a seller quoting one as their origin is the cheapest fraud to
# detect. Named $PRODUCING_TYPES so the per-row $isProducing cannot collide with it: PowerShell
# is case-insensitive, and $true -contains 'LEL' evaluates TRUE because a non-empty string coerces
# to $true, so the collision silently passed every licence. Second time this bit in one script.
$PRODUCING_TYPES = @('LML','SML','AMR','MPL','LGL','SGL','P_LML','P_SML')

$SOURCES_JSON = @'
[{"id":"ngdr","name":"NGDR active mineral licence register","publisher":"Geological Survey Department, Zambia","url":"https://ngdr.gsb.gov.zm/","snapshot":"2025-06-18","covers":"licence code, type, holder, commodities, area, expiry, coordinates"},{"id":"mmmd_notices","name":"Cancellation and default notices","publisher":"Ministry of Mines and Minerals Development, Zambia","url":"https://www.mmmd.gov.zm/","snapshot":"2025-06-18","covers":"MLC 78 cancellations, 2023 and 2025 public default notices"},{"id":"pacra","name":"PACRA companies registry","publisher":"Patents and Companies Registration Agency, Zambia","url":"https://www.pacra.org.zm/","snapshot":"2026-07-29","covers":"entity number, status, declared business, beneficial ownership, annual returns"}]
'@.Trim()

$DISCLAIM_ACTIVE = 'Derived from published Zambian government registers on the snapshot dates in sources. A pass means these four public records agree on the date shown. It is not an endorsement, a title opinion, or evidence that any material was actually produced. Verify against the primary source before relying on it commercially.'
$DISCLAIM_REVOKED = 'This code is absent from the active register AND named in a published adverse notice. Treat a seller offering it as an origin accordingly. Absence alone would be inconclusive; the notice is what makes this determinate.'

function Norm([string]$n) {
    if (-not $n) { return '' }
    $x = ($n -replace '\([^)]*\)','')
    $x = ($x.ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b',' '
    ($x -replace '\s+',' ').Trim()
}

$byCode = @{}
foreach ($p in $LIC.points) {
    $c = "$($p[2])".ToUpper().Trim()
    if (-not $c) { continue }
    if ($byCode.ContainsKey($c)) { continue }   # first record wins; duplicates are re-issues
    $byCode[$c] = $p
}
Write-Host ("distinct licence codes on the active register: {0}" -f $byCode.Count)

$licDir = Join-Path $apiRoot 'licence'
New-Item -ItemType Directory -Force -Path $licDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $apiRoot 'bulk') | Out-Null

$bulk = New-Object System.Text.StringBuilder
$nVerified = 0; $nEligible = 0; $nRevoked = 0; $nWritten = 0
$first = $true

function Adverse-Json($advArr) {
    if (-not $advArr -or $advArr.Count -eq 0) { return '[]' }
    $parts = foreach ($a in $advArr) {
        '{"notice":' + (J $a.notice) + ',"list_id":' + (J $a.list_id) +
        ',"holder_as_listed":' + (J $a.holder_as_listed) + ',"detail":' + (JN $a.detail) + '}'
    }
    '[' + ($parts -join ',') + ']'
}

foreach ($code in ($byCode.Keys | Sort-Object)) {
    $p = $byCode[$code]
    $type = "$($p[3])"
    $holder = (("$($p[4])") -replace '\s*\(\d+(\.\d+)?%\)','').Trim()
    $key = Norm $holder
    $reg = if ($key -and $REGISTRY.ContainsKey($key)) { $REGISTRY[$key] } else { $null }
    $flag = [int]$p[8]
    $adv = if ($ADVERSE.ContainsKey($code)) { $ADVERSE[$code].ToArray() } else { $null }

    $isProducing = $PRODUCING_TYPES -contains $type
    $typeName = if ($TYPE_NAME[$type]) { $TYPE_NAME[$type] } else { $type }
    $flagText = switch ($flag) {
        3 { 'Listed in the 2025 default notice and cancelled at MLC 78' }
        2 { 'Cancelled at MLC 78 (April 2024)' }
        1 { 'Listed in the June 2025 public default notice' }
        default { 'Not listed in any cancellation or default notice' }
    }
    $boOk = ($null -ne $reg -and [int]$reg.bo -eq 1)
    $arOk = ($null -ne $reg -and [int]$reg.ar -eq 1)
    $boDetail = if ($null -eq $reg) { 'No companies-registry record matched this holder' }
                elseif ($boOk) { 'Declared with PACRA' } else { 'Not declared with PACRA' }
    $arDetail = if ($null -eq $reg) { 'No companies-registry record matched this holder' }
                elseif ($arOk) { 'Filed' } else { 'Not filed' }

    $passed = 0
    if ($isProducing) { $passed++ }
    if ($flag -eq 0) { $passed++ }
    if ($boOk) { $passed++ }
    if ($arOk) { $passed++ }
    $verified = ($passed -eq 4)
    if ($verified) { $nVerified++ }
    if ($isProducing) { $nEligible++ }
    $grade = switch ($passed) { 4 {'A'} 3 {'B'} 2 {'C'} default {'D'} }

    $comm = if ("$($p[5])") { (("$($p[5])" -split ',\s*') | ForEach-Object { J $_ }) -join ',' } else { '' }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{')
    [void]$sb.Append('"schema":' + (J $SCHEMA))
    [void]$sb.Append(',"generated":' + (J $GENERATED))
    [void]$sb.Append(',"licence_code":' + (J $code))
    [void]$sb.Append(',"found":true,"on_active_register":true,"status":"active"')
    [void]$sb.Append(',"verified":' + (B $verified))
    [void]$sb.Append(',"origin_eligible":' + (B $isProducing))
    [void]$sb.Append(',"grade":' + (J $grade))
    [void]$sb.Append(',"checks_passed":' + $passed + ',"checks_total":4')
    [void]$sb.Append(',"checks":[')
    [void]$sb.Append('{"id":"licence_permits_production","pass":' + (B $isProducing) +
        ',"requirement":"The licence class must permit minerals to be produced for sale","detail":' +
        (J $(if ($isProducing) { "$typeName permits production" } else { "$typeName cannot lawfully produce minerals for sale" })) +
        ',"source":"ngdr"}')
    [void]$sb.Append(',{"id":"no_adverse_notice","pass":' + (B ($flag -eq 0)) +
        ',"requirement":"The licence must not appear in a cancellation or default notice","detail":' +
        (J $flagText) + ',"source":"mmmd_notices"}')
    [void]$sb.Append(',{"id":"beneficial_ownership_declared","pass":' + (B $boOk) +
        ',"requirement":"The holder must have declared its beneficial owners","detail":' +
        (J $boDetail) + ',"source":"pacra"}')
    [void]$sb.Append(',{"id":"annual_returns_filed","pass":' + (B $arOk) +
        ',"requirement":"The holder must be current on statutory annual returns","detail":' +
        (J $arDetail) + ',"source":"pacra"}')
    [void]$sb.Append(']')
    [void]$sb.Append(',"licence":{"code":' + (J $code) + ',"type":' + (J $type) +
        ',"type_name":' + (J $typeName) + ',"commodities":[' + $comm + ']' +
        ',"hectares":' + ([int]$p[7]) + ',"expires":' + (JN $p[6]) +
        ',"centroid":{"lat":' + ([double]$p[1]) + ',"lng":' + ([double]$p[0]) + '}}')
    [void]$sb.Append(',"holder":{"name":' + (J $holder) +
        ',"registry_matched":' + (B ($null -ne $reg)) +
        ',"registry_number":' + $(if ($reg) { JN $reg.no } else { 'null' }) +
        ',"registered_name":' + $(if ($reg) { JN $reg.n } else { 'null' }) +
        ',"registered_on":' + $(if ($reg) { JN $reg.d } else { 'null' }) +
        ',"registry_status":' + $(if ($reg) { JN $reg.st } else { 'null' }) +
        ',"declared_business":' + $(if ($reg) { JN $reg.b } else { 'null' }) +
        ',"beneficial_ownership_declared":' + $(if ($reg) { B $boOk } else { 'null' }) +
        ',"annual_returns_filed":' + $(if ($reg) { B $arOk } else { 'null' }) + '}')
    [void]$sb.Append(',"adverse_notices":' + (Adverse-Json $adv))
    [void]$sb.Append(',"sources":' + $SOURCES_JSON)
    [void]$sb.Append(',"disclaimer":' + (J $DISCLAIM_ACTIVE))
    [void]$sb.Append('}')
    [IO.File]::WriteAllText((Join-Path $licDir "$code.json"), $sb.ToString(), $u)
    $nWritten++

    if (-not $first) { [void]$bulk.Append(',') }
    $first = $false
    [void]$bulk.Append('{"code":' + (J $code) + ',"verified":' + (B $verified) +
        ',"origin_eligible":' + (B $isProducing) + ',"grade":' + (J $grade) +
        ',"checks_passed":' + $passed + ',"type":' + (J $type) + ',"status":"active"}')
}

# ---------- codes off the register because they were revoked ----------
foreach ($code in ($ADVERSE.Keys | Sort-Object)) {
    if ($byCode.ContainsKey($code)) { continue }
    $adv = $ADVERSE[$code].ToArray()
    $nRevoked++
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{"schema":' + (J $SCHEMA) + ',"generated":' + (J $GENERATED))
    [void]$sb.Append(',"licence_code":' + (J $code))
    [void]$sb.Append(',"found":true,"on_active_register":false,"status":"revoked_or_lapsed"')
    [void]$sb.Append(',"verified":false,"origin_eligible":false,"grade":"D"')
    [void]$sb.Append(',"checks_passed":0,"checks_total":4')
    [void]$sb.Append(',"checks":[{"id":"on_active_register","pass":false,"requirement":' +
        '"The licence must appear on the active mineral licence register","detail":' +
        (J 'Absent from the active register and named in an adverse notice, which is why') +
        ',"source":"mmmd_notices"}]')
    [void]$sb.Append(',"licence":null')
    [void]$sb.Append(',"holder":{"name":' + (J $adv[0].holder_as_listed) + ',"registry_matched":false}')
    [void]$sb.Append(',"adverse_notices":' + (Adverse-Json $adv))
    [void]$sb.Append(',"sources":' + $SOURCES_JSON)
    [void]$sb.Append(',"disclaimer":' + (J $DISCLAIM_REVOKED) + '}')
    [IO.File]::WriteAllText((Join-Path $licDir "$code.json"), $sb.ToString(), $u)
    $nWritten++
    if (-not $first) { [void]$bulk.Append(',') }
    $first = $false
    [void]$bulk.Append('{"code":' + (J $code) + ',"verified":false,"origin_eligible":false' +
        ',"grade":"D","checks_passed":0,"type":null,"status":"revoked_or_lapsed"}')
}

# ---------- bulk ----------
$bulkJson = '{"schema":' + (J $SCHEMA) + ',"generated":' + (J $GENERATED) +
    ',"note":' + (J 'Every known licence code with its verdict. Fetch one licence file for the full check detail.') +
    ',"count":' + $nWritten + ',"results":[' + $bulk.ToString() + ']}'
[IO.File]::WriteAllText((Join-Path $apiRoot 'bulk\gate.json'), $bulkJson, $u)

# ---------- index ----------
$idx = [ordered]@{
    schema = $SCHEMA; generated = $GENERATED
    service = 'Zambia Mineral Origin Gate'
    description = 'Resolves a Zambian mineral licence code to a binary verified or not-verified verdict against four checks, each traceable to a published government register.'
    base_url = $BASE
    endpoints = [ordered]@{
        licence = "$BASE/licence/{LICENCE_CODE}.json"
        bulk = "$BASE/bulk/gate.json"
        openapi = "$BASE/openapi.json"
    }
    gate_definition = 'verified is true only when all four checks pass. Deliberately binary: a rich per-lot provenance payload fragments a fungible commodity and harms price discovery, whereas a binary gate concentrates liquidity into a single pool. Check detail is returned for audit, not for trading.'
    checks = @(
        [ordered]@{ id='licence_permits_production'; source='ngdr'; requirement='The licence class must permit minerals to be produced for sale' }
        [ordered]@{ id='no_adverse_notice'; source='mmmd_notices'; requirement='The licence must not appear in a cancellation or default notice' }
        [ordered]@{ id='beneficial_ownership_declared'; source='pacra'; requirement='The holder must have declared its beneficial owners' }
        [ordered]@{ id='annual_returns_filed'; source='pacra'; requirement='The holder must be current on statutory annual returns' }
    )
    counts = [ordered]@{
        codes_total = $nWritten
        on_active_register = $byCode.Count
        revoked_or_lapsed = $nRevoked
        origin_eligible = $nEligible
        not_origin_eligible = ($byCode.Count - $nEligible)
        verified = $nVerified
    }
    sources = ($SOURCES_JSON | ConvertFrom-Json)
    licence_terms = 'Derived from Zambian public registers. Reuse freely with attribution to this project and to the underlying government sources named above.'
}
[IO.File]::WriteAllText((Join-Path $apiRoot 'index.json'), ($idx | ConvertTo-Json -Depth 8), $u)

# ---------- openapi ----------
$oa = [ordered]@{
    openapi = '3.1.0'
    info = [ordered]@{ title='Zambia Mineral Origin Gate'; version='1.0.0'
        description='Static JSON API. One file per Zambian mineral licence code, returning a binary origin verdict plus four auditable checks against published government registers. Served by GitHub Pages with permissive CORS, so it is callable from a browser or an off-chain worker without a proxy.' }
    servers = @(@{ url=$BASE })
    paths = [ordered]@{
        '/index.json' = @{ get = [ordered]@{ summary='Service metadata, check definitions, counts and source provenance'; operationId='getIndex'
            responses=@{ '200'=@{ description='Service description' } } } }
        '/licence/{licenceCode}.json' = @{ get = [ordered]@{
            summary='Origin gate verdict for one licence code'
            description='Codes are upper case, for example 40199-HQ-AMR. A code absent from the active register but named in an adverse notice returns found true with status revoked_or_lapsed, so revoked is never confused with unknown. A genuinely unknown code returns HTTP 404.'
            operationId='getLicence'
            parameters=@(@{ name='licenceCode'; 'in'='path'; required=$true; schema=@{ type='string'; example='40199-HQ-AMR' } })
            responses=[ordered]@{
                '200'=@{ description='Gate verdict'; content=@{ 'application/json'=@{ schema=@{ '$ref'='#/components/schemas/GateResponse' } } } }
                '404'=@{ description='No such licence code in this snapshot' } } } }
        '/bulk/gate.json' = @{ get = [ordered]@{ summary='Every code with its verdict'; operationId='getBulk'
            responses=@{ '200'=@{ description='All verdicts' } } } }
    }
    components = @{ schemas = @{ GateResponse = [ordered]@{
        type='object'
        required=@('schema','licence_code','found','verified','origin_eligible','checks')
        properties=[ordered]@{
            schema=@{ type='string'; const=$SCHEMA }
            generated=@{ type='string'; format='date' }
            licence_code=@{ type='string' }
            found=@{ type='boolean' }
            on_active_register=@{ type='boolean' }
            status=@{ type='string'; enum=@('active','revoked_or_lapsed') }
            verified=@{ type='boolean'; description='True only when all four checks pass. This is the tradeable signal.' }
            origin_eligible=@{ type='boolean'; description='True when the licence class may lawfully produce minerals for sale.' }
            grade=@{ type='string'; enum=@('A','B','C','D') }
            checks_passed=@{ type='integer'; minimum=0; maximum=4 }
            checks_total=@{ type='integer'; const=4 }
            checks=@{ type='array'; items=@{ type='object'; properties=[ordered]@{
                id=@{ type='string' }; pass=@{ type='boolean' }
                requirement=@{ type='string' }; detail=@{ type='string' }
                source=@{ type='string'; description='id of an entry in sources' } } } }
            licence=@{ type=@('object','null') }
            holder=@{ type='object' }
            adverse_notices=@{ type='array'; items=@{ type='object' } }
            sources=@{ type='array'; items=@{ type='object' } }
            disclaimer=@{ type='string' }
        } } } }
}
[IO.File]::WriteAllText((Join-Path $apiRoot 'openapi.json'), ($oa | ConvertTo-Json -Depth 12), $u)

Write-Host ""
Write-Host ("wrote {0} licence endpoints" -f $nWritten)
Write-Host ("  on the active register : {0}" -f $byCode.Count)
Write-Host ("  revoked or lapsed      : {0}" -f $nRevoked)
Write-Host ("  origin eligible        : {0}  ({1} cannot lawfully produce)" -f $nEligible, ($byCode.Count - $nEligible))
Write-Host ("  verified, 4 of 4       : {0}  ({1}% of active)" -f $nVerified, [math]::Round(100*$nVerified/$byCode.Count,1))
Write-Host ("index.json, openapi.json and bulk/gate.json written under {0}" -f $apiRoot)
