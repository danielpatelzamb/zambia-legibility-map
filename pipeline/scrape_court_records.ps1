# scrape_court_records.ps1
# Cross-references Zambian mining license holders against ZambiaLII (Peachjam) court records.
# RESUMABLE: checkpoints to data\gov\court\court_hits.json every 25 names; on restart,
# names already in the checkpoint are skipped. Just re-run the same command to resume.
#
# Usage:  powershell -ExecutionPolicy Bypass -File pipeline\scrape_court_records.ps1 [-MaxNames 700] [-ThrottleMs 1500]
#
# Endpoint (verified 2026-07-23):
#   GET https://zambialii.org/search/api/documents/?search=%22<NAME>%22&page=1&nature=Judgment
#   -> JSON { count, facets, entity_results_html, results_html, trace_id, can_semantic }
#   results_html is a rendered HTML list; each hit is a <li class="mb-4 hit"> with an
#   <a href="/akn/..."> title link and <span class="me-3"> date / court spans.

param(
    [int]$MaxNames = 700,
    [int]$ThrottleMs = 1500
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Root       = Split-Path -Parent $PSScriptRoot
$DataDir    = Join-Path $Root 'data'
$GovDir     = Join-Path $DataDir 'gov'
$CourtDir   = Join-Path $GovDir 'court'
$Checkpoint = Join-Path $CourtDir 'court_hits.json'
$Endpoint   = 'https://zambialii.org/search/api/documents/'
$UA         = 'Mozilla/5.0 (compatible; research-kyc-crossref; +https://github.com/danielpatelzamb/zambia-legibility-map)'

if (-not (Test-Path $CourtDir)) { New-Item -ItemType Directory -Force $CourtDir | Out-Null }

# ---------------------------------------------------------------- helpers ---

function Clean-Holders([string]$raw) {
    # Split multi-party holder strings ("A (60%); B (40%)"), strip "(NN%)" / "(NN.N%)",
    # trim, collapse whitespace. Returns array of clean names.
    $out = @()
    if ([string]::IsNullOrWhiteSpace($raw)) { return $out }
    foreach ($part in ($raw -split ';')) {
        $n = $part -replace '\(\s*\d+(\.\d+)?\s*%\s*\)', ''
        $n = ($n -replace '\s+', ' ').Trim().Trim(',').Trim()
        if ($n.Length -gt 0) { $out += $n }
    }
    return $out
}

function Parse-Hits([string]$html, [int]$max = 5) {
    $hits = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($html)) { return $hits }
    $chunks = $html -split '<li class="mb-4 hit'
    foreach ($chunk in ($chunks | Select-Object -Skip 1)) {
        if ($hits.Count -ge $max) { break }
        $u = $null; $t = $null; $d = $null; $c = $null
        $m = [regex]::Match($chunk, 'href="([^"]+)"')
        if ($m.Success) { $u = 'https://zambialii.org' + $m.Groups[1].Value }
        $m = [regex]::Match($chunk, 'data-position="\d+">\s*(.*?)</a>', 'Singleline')
        if ($m.Success) {
            $t = ($m.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()
        }
        $spans = [regex]::Matches($chunk, '<span class="me-3">([^<]+)</span>')
        if ($spans.Count -ge 1) { $d = $spans[0].Groups[1].Value.Trim() }
        if ($spans.Count -ge 2) { $c = $spans[1].Groups[1].Value.Trim() }
        if ($u) { [void]$hits.Add([pscustomobject]@{ t = $t; d = $d; c = $c; u = $u }) }
    }
    return $hits
}

function Save-Checkpoint($namesTable) {
    $obj = [ordered]@{
        endpoint = $Endpoint + '?search=%22NAME%22&page=1&nature=Judgment'
        scraped  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        names    = $namesTable
    }
    $json = $obj | ConvertTo-Json -Depth 6
    $tmp = $Checkpoint + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -Force $tmp $Checkpoint
}

# ------------------------------------------------------ build the name list ---

Write-Host "Loading source data..."

# 1. License points (JS file; one point-array per line)
$pointsFile = Join-Path $DataDir 'licenses_points.js'
$prodTypes = @('SML', 'LML', 'MPL', 'LPL', 'P_SML', 'P_LML')
$prodHolders = New-Object System.Collections.ArrayList
foreach ($line in [System.IO.File]::ReadLines($pointsFile)) {
    $l = $line.Trim()
    if (-not $l.StartsWith('[')) { continue }
    $l = $l.TrimEnd(',').Trim()
    if (-not $l.EndsWith(']')) { continue }
    try { $row = $l | ConvertFrom-Json } catch { continue }
    if ($row.Count -lt 9) { continue }
    $typecode = [string]$row[3]
    if ($prodTypes -contains $typecode) {
        foreach ($h in (Clean-Holders ([string]$row[4]))) { [void]$prodHolders.Add($h) }
    }
}

# 2. Adverse lists
$advFiles = @(
    (Join-Path $GovDir 'mmmd_mlc78_cancellations_2024-04.json'),
    (Join-Path $GovDir 'mmmd_default_notice_2025-06-18.json'),
    (Join-Path $GovDir 'mmmd_default_notice_2023-10.json')
)
$mlc78Holders = New-Object System.Collections.ArrayList
$adverseCounts = @{}   # UPPER name -> count of adverse rows
foreach ($f in $advFiles) {
    $rows = Get-Content -Raw $f | ConvertFrom-Json
    $isMlc78 = $f -like '*mlc78*'
    foreach ($row in $rows) {
        foreach ($h in (Clean-Holders ([string]$row.holder))) {
            $key = $h.ToUpperInvariant()
            if ($adverseCounts.ContainsKey($key)) { $adverseCounts[$key] = $adverseCounts[$key] + 1 }
            else { $adverseCounts[$key] = 1 }
            if ($isMlc78) { [void]$mlc78Holders.Add($h) }
        }
    }
}
$multiAdverse = $adverseCounts.GetEnumerator() | Where-Object { $_.Value -ge 2 } | ForEach-Object { $_.Key }

# Merge with priority: (1) production/processing license holders, (2) MLC-78 cancellations,
# (3) 2+ adverse rows. Dedupe case-insensitively, keep first occurrence, sorted within group
# for deterministic resume order. Skip names < 6 chars.
$seen = @{}
$queue = New-Object System.Collections.ArrayList
foreach ($group in @(
        ($prodHolders  | Sort-Object -Unique),
        ($mlc78Holders | Sort-Object -Unique),
        ($multiAdverse | Sort-Object -Unique))) {
    foreach ($n in $group) {
        if ($null -eq $n) { continue }
        $name = ([string]$n).Trim()
        if ($name.Length -lt 6) { continue }
        $key = $name.ToUpperInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        [void]$queue.Add($name)
    }
}
if ($queue.Count -gt $MaxNames) { $queue = $queue.GetRange(0, $MaxNames) }
Write-Host ("Name list built: {0} names (prod-license holders: {1} unique, MLC-78: {2} unique, 2+ adverse: {3})" -f `
    $queue.Count, ($prodHolders | Sort-Object -Unique).Count, ($mlc78Holders | Sort-Object -Unique).Count, ($multiAdverse | Measure-Object).Count)

# ------------------------------------------------------------- checkpoint ---

$namesTable = [ordered]@{}
if (Test-Path $Checkpoint) {
    try {
        $prev = Get-Content -Raw $Checkpoint | ConvertFrom-Json
        foreach ($p in $prev.names.PSObject.Properties) {
            $namesTable[$p.Name] = $p.Value
        }
        Write-Host ("Checkpoint loaded: {0} names already scraped, will be skipped." -f $namesTable.Count)
    } catch {
        Write-Warning "Checkpoint exists but could not be parsed; starting fresh. ($($_.Exception.Message))"
    }
}

$todo = @($queue | Where-Object { -not $namesTable.Contains($_.ToUpperInvariant()) })
Write-Host ("To query this run: {0} names" -f $todo.Count)

# ------------------------------------------------------------------ scrape ---

$done = 0
$blocked = 0
foreach ($name in $todo) {
    $key = $name.ToUpperInvariant()
    $q = [uri]::EscapeDataString('"' + $name + '"')
    $url = "$Endpoint`?search=$q&page=1&nature=Judgment"

    $resp = $null
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Uri $url -TimeoutSec 40 -Headers @{
                'Accept' = 'application/json'; 'User-Agent' = $UA }
            break
        } catch {
            $status = 0
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 403 -or $status -eq 429) {
                $blocked++
                Write-Warning ("HTTP {0} for '{1}' - possible rate limit/block." -f $status, $name)
                if ($blocked -ge 3) {
                    Write-Warning "Blocked 3 times - STOPPING (not evading). Checkpoint saved; re-run later to resume."
                    Save-Checkpoint $namesTable
                    exit 2
                }
                Start-Sleep -Seconds 30
            } elseif ($attempt -eq 1) {
                Write-Warning ("Request failed for '{0}' (attempt 1): {1}; retrying in 5s" -f $name, $_.Exception.Message)
                Start-Sleep -Seconds 5
            } else {
                Write-Warning ("Request failed for '{0}' (attempt 2): {1}; skipping this run (not checkpointed, will retry on resume)" -f $name, $_.Exception.Message)
            }
        }
    }
    if ($null -eq $resp) { Start-Sleep -Milliseconds $ThrottleMs; continue }

    $n = [int]$resp.count
    $hits = @()
    if ($n -gt 0) { $hits = @(Parse-Hits $resp.results_html 5) }
    $namesTable[$key] = [pscustomobject]@{ n = $n; hits = $hits }
    $done++
    Write-Host ("[{0}/{1}] {2}  ->  {3} judgment(s)" -f $done, $todo.Count, $name, $n)

    if ($done % 25 -eq 0) {
        Save-Checkpoint $namesTable
        Write-Host ("  checkpoint saved ({0} total names)" -f $namesTable.Count)
    }
    Start-Sleep -Milliseconds $ThrottleMs
}

Save-Checkpoint $namesTable
$withHits = @($namesTable.Values | Where-Object { $_.n -gt 0 }).Count
Write-Host ""
Write-Host ("DONE. Total names in checkpoint: {0}; queried this run: {1}; names with >=1 judgment: {2}" -f $namesTable.Count, $done, $withHits)
Write-Host ("Checkpoint: {0}" -f $Checkpoint)
