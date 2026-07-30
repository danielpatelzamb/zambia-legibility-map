# probe_holder_web.ps1
# Bulk contact discovery for licence holders WITHOUT using search engines (they are all
# CAPTCHA-walled / rate-capped as of 2026-07-28). For each holder this:
#   1. generates candidate domains from the company-name stem (.com / .co.zm / .zm)
#   2. probes each; on a live site, fetches it (and /contact, /contact-us, /about) and extracts
#      published emails and Zambian phone numbers
#   3. probes the plausible LinkedIn company slug
# Only ORGANISATIONAL, self-published contact data is captured. No brokers, no personal accounts.
# Resumable: re-run to continue; holders already in the output are skipped.
param(
    [string]$Target = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\holders_wave3_target.csv'),
    [string]$Out    = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\web_probe_results.json'),
    [int]$SaveEvery = 20
)
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'

# name -> domain stems. Drops legal suffixes and generic filler, keeps the distinctive words.
function Get-Stems([string]$name) {
    $n = ($name.ToUpper() -replace '[^A-Z0-9 ]', ' ') -replace '\s+', ' '
    $drop = @('LIMITED','LTD','PLC','COMPANY','CO','INCORPORATED','INC','THE','AND','OF','ZAMBIA','ZAMBIAN')
    $words = @($n.Trim() -split ' ' | Where-Object { $_ -and $drop -notcontains $_ })
    if (-not $words.Count) { return @() }
    $stems = New-Object System.Collections.Generic.List[string]
    $stems.Add(($words -join '').ToLower())                                  # allwords
    if ($words.Count -ge 2) { $stems.Add((($words[0..1]) -join '').ToLower()) }  # first two
    $stems.Add($words[0].ToLower())                                          # first word
    @($stems | Where-Object { $_.Length -ge 4 -and $_.Length -le 40 } | Select-Object -Unique)
}

function Get-Contacts([string]$html) {
    $emails = @([regex]::Matches($html, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}') |
        ForEach-Object { $_.Value.ToLower() } |
        Where-Object { $_ -notmatch '\.(png|jpg|jpeg|gif|svg|webp|css|js)$' -and $_ -notmatch '^(no-?reply|postmaster|abuse|example|test|user|name|email|your)@' -and $_ -notmatch 'sentry|wixpress|godaddy|cloudflare|w3\.org|schema\.org' } |
        Select-Object -Unique)
    $phones = @([regex]::Matches($html, '(?:\+?260|\(0\)|\b0)[\s\-\.]?\d{2,3}[\s\-\.]?\d{3}[\s\-\.]?\d{3,4}') |
        ForEach-Object { ($_.Value -replace '\s+',' ').Trim() } | Select-Object -Unique)
    @{ emails = $emails; phones = $phones }
}

$holders = @(Import-Csv $Target)
Write-Host "holders to probe: $($holders.Count)"

$results = [System.Collections.Generic.List[object]]::new()
$seen = @{}
if (Test-Path $Out) {
    try { foreach ($r in (Get-Content $Out -Raw -Encoding UTF8 | ConvertFrom-Json)) { $results.Add($r); $seen[$r.holder] = $true } ; Write-Host "resuming: $($results.Count) done" } catch {}
}
function Save-Out {
    $json = if ($results.Count -eq 1) { '[' + ($results[0] | ConvertTo-Json -Depth 5 -Compress) + ']' } else { $results | ConvertTo-Json -Depth 5 }
    [System.IO.File]::WriteAllText($Out, $json, [System.Text.Encoding]::UTF8)
}

$i = 0; $sites = 0; $withContact = 0
foreach ($h in $holders) {
    $i++
    if ($seen[$h.holder]) { continue }
    $liveUrl = $null; $emails = @(); $phones = @(); $tried = @(); $li = $null
    foreach ($stem in (Get-Stems $h.holder)) {
        foreach ($tld in @('com','co.zm','zm')) {
            $u = "https://$stem.$tld"
            $tried += "$stem.$tld"
            try {
                $r = Invoke-WebRequest -Uri $u -UserAgent $ua -TimeoutSec 12 -UseBasicParsing -MaximumRedirection 3
                if ($r.StatusCode -eq 200 -and $r.Content.Length -gt 800) {
                    # reject parked / for-sale placeholders
                    if ($r.Content -match 'HugeDomains|domain (?:is )?for sale|buy this domain|GoDaddy.*parked|Sedo|DomainMarket|Afternic') { continue }
                    $liveUrl = $u
                    $c = Get-Contacts $r.Content
                    $emails += $c.emails; $phones += $c.phones
                    foreach ($sub in @('contact','contact-us','about','about-us','contacts')) {
                        try {
                            $r2 = Invoke-WebRequest -Uri "$u/$sub" -UserAgent $ua -TimeoutSec 10 -UseBasicParsing -MaximumRedirection 3
                            if ($r2.StatusCode -eq 200) { $c2 = Get-Contacts $r2.Content; $emails += $c2.emails; $phones += $c2.phones }
                        } catch {}
                    }
                    break
                }
            } catch {}
        }
        if ($liveUrl) { break }
    }
    # LinkedIn company slug probe (best-effort; LinkedIn often blocks automation)
    foreach ($stem in (Get-Stems $h.holder)) {
        try {
            $rl = Invoke-WebRequest -Uri "https://www.linkedin.com/company/$stem" -UserAgent $ua -TimeoutSec 10 -UseBasicParsing -MaximumRedirection 2
            if ($rl.StatusCode -eq 200 -and $rl.Content -match 'linkedin.com/company/') { $li = "https://www.linkedin.com/company/$stem"; break }
        } catch {}
    }
    $emails = @($emails | Select-Object -Unique); $phones = @($phones | Select-Object -Unique)
    if ($liveUrl) { $sites++ }
    if ($emails.Count -or $phones.Count) { $withContact++ }
    $results.Add([pscustomobject]@{
        holder = $h.holder; segment = $h.segment
        website = $liveUrl
        emails = $emails
        phones = $phones
        linkedin = $li
        domains_tried = $tried
        method = 'bulk_domain_probe_no_search'
        note = if ($liveUrl) { 'live site found by domain-stem probe; contacts are self-published on that site' } else { 'no live site at any candidate domain' }
    })
    $seen[$h.holder] = $true
    if (($i % $SaveEvery) -eq 0) { Save-Out; Write-Host ("  {0}/{1}  sites {2}  with-contact {3}" -f $i, $holders.Count, $sites, $withContact) }
}
Save-Out
Write-Host "DONE. probed $($results.Count) | live sites $sites | with email/phone $withContact"
