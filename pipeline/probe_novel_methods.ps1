# probe_novel_methods.ps1
# Second-pass contact discovery for holders where conventional research found NOTHING.
# Deliberately avoids search engines (all CAPTCHA-walled as of 2026-07-28) and uses four
# techniques the first pass never tried:
#
#   1. WAYBACK MACHINE (archive.org CDX) — a company's site may be dead now but archived.
#      Several holders were found with dead domains (karibaminerals.com, starchoicemining.com,
#      philtoninvestments.com all have captures). Fetch the newest 200-status snapshot of the
#      home + contact pages and extract published contacts from it.
#   2. CERTIFICATE TRANSPARENCY (crt.sh) — every TLS cert ever issued is public. Querying a
#      candidate domain returns the real hostnames a company uses, including subdomains and
#      spellings you would never guess (verified: zamefa.com -> www/mta-sts/wildcard).
#   3. MX RECORD VALIDATION — an MX record proves the domain accepts mail, which turns a guessed
#      role address (info@, admin@, sales@) into a plausible one rather than a fabrication.
#      We record the MX provider as evidence and mark such addresses INFERRED, never asserted.
#   4. TLD BREADTH — .org / .net / .africa / .co.za are tried, not just .com/.co.zm/.zm.
#
# Everything captured is self-published organisational data. Nothing personal, no brokers.
# Resumable: re-run to continue.
param(
    [string]$Out       = (Join-Path (Split-Path $PSScriptRoot -Parent) 'research\novel_probe_results.json'),
    [string]$Dataset   = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dataset'),
    [int]$SaveEvery    = 15,
    [int]$MaxHolders   = 0      # 0 = all
)
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'

function Get-Stems([string]$name) {
    $n = ($name.ToUpper() -replace '[^A-Z0-9 ]', ' ') -replace '\s+', ' '
    $drop = @('LIMITED','LTD','PLC','COMPANY','CO','INCORPORATED','INC','THE','AND','OF','ZAMBIA','ZAMBIAN')
    $w = @($n.Trim() -split ' ' | Where-Object { $_ -and $drop -notcontains $_ })
    if (-not $w.Count) { return @() }
    $s = New-Object System.Collections.Generic.List[string]
    $s.Add(($w -join '').ToLower())
    if ($w.Count -ge 2) { $s.Add((($w[0..1]) -join '').ToLower()) }
    $s.Add($w[0].ToLower())
    @($s | Where-Object { $_.Length -ge 4 -and $_.Length -le 40 } | Select-Object -Unique)
}
function Get-Contacts([string]$html) {
    $emails = @([regex]::Matches($html, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}') |
        ForEach-Object { $_.Value.ToLower() } |
        Where-Object { $_ -notmatch '\.(png|jpg|jpeg|gif|svg|webp|css|js)$' -and
                       $_ -notmatch '^(no-?reply|postmaster|abuse|example|test|user|name|email|your|sentry)@' -and
                       $_ -notmatch 'wixpress|godaddy|cloudflare|w3\.org|schema\.org|archive\.org|wordpress' } |
        Select-Object -Unique)
    $phones = @([regex]::Matches($html, '(?:\+?260|\(0\)|\b0)[\s\-\.]?\d{2,3}[\s\-\.]?\d{3}[\s\-\.]?\d{3,4}') |
        ForEach-Object { ($_.Value -replace '\s+',' ').Trim() } | Select-Object -Unique)
    @{ emails = $emails; phones = $phones }
}

# --- build the worklist: holders already researched with NO usable channel ---
$hcPath = Join-Path $Dataset 'holder_contacts.csv'
$work = @(Import-Csv $hcPath |
    Where-Object { $_.reachable -ne 'yes' -and $_.search_coverage -ne 'not_researched' } |
    Select-Object holder, segment, notes)
if ($MaxHolders -gt 0) { $work = @($work | Select-Object -First $MaxHolders) }
Write-Host "holders with no channel to re-attack: $($work.Count)"

$results = [System.Collections.Generic.List[object]]::new()
$seen = @{}
if (Test-Path $Out) { try { foreach ($r in (Get-Content $Out -Raw -Encoding UTF8 | ConvertFrom-Json)) { $results.Add($r); $seen[$r.holder]=$true } ; Write-Host "resuming: $($results.Count)" } catch {} }
function Save-Out {
    $json = if ($results.Count -eq 1) { '[' + ($results[0] | ConvertTo-Json -Depth 6 -Compress) + ']' } else { $results | ConvertTo-Json -Depth 6 }
    [System.IO.File]::WriteAllText($Out, $json, [System.Text.Encoding]::UTF8)
}

$i=0; $found=0
foreach ($h in $work) {
    $i++
    if ($seen[$h.holder]) { continue }
    $stems = Get-Stems $h.holder
    $rec = [ordered]@{
        holder = $h.holder; segment = $h.segment
        wayback_url = $null; wayback_date = $null
        live_domain = $null; ct_hostnames = @()
        mx_domain = $null; mx_provider = $null
        emails = @(); phones = @()
        inferred_role_email = $null
        method = @(); note = $null
    }
    foreach ($stem in $stems) {
        foreach ($tld in @('com','co.zm','zm','org','net','africa','co.za')) {
            $dom = "$stem.$tld"

            # (2) certificate transparency: does this hostname have any cert ever?
            if (-not $rec.ct_hostnames.Count) {
                try {
                    $ct = Invoke-WebRequest -Uri ("https://crt.sh/?q=" + [uri]::EscapeDataString($dom) + "&output=json") -UserAgent $ua -TimeoutSec 45 -UseBasicParsing
                    if ($ct.Content.Length -gt 5) {
                        $names = @(($ct.Content | ConvertFrom-Json).name_value -split "`n" | Where-Object {$_} | ForEach-Object { $_.Trim().ToLower() } | Select-Object -Unique)
                        if ($names.Count) { $rec.ct_hostnames = $names; $rec.method += 'cert_transparency' }
                    }
                } catch {}
            }

            # (3) MX: does the domain accept mail?
            if (-not $rec.mx_domain) {
                $mx = Resolve-DnsName -Name $dom -Type MX -ErrorAction SilentlyContinue
                $mxh = @($mx | Where-Object { $_.NameExchange } | ForEach-Object { $_.NameExchange })
                if ($mxh.Count) {
                    $rec.mx_domain = $dom; $rec.mx_provider = ($mxh | Select-Object -First 2) -join ', '
                    $rec.inferred_role_email = "info@$dom"
                    $rec.method += 'mx_validated'
                }
            }

            # (1) wayback: was there ever a live site?
            if (-not $rec.wayback_url) {
                try {
                    $cdx = Invoke-WebRequest -Uri "https://web.archive.org/cdx/search/cdx?url=$dom&output=json&limit=4&filter=statuscode:200&collapse=urlkey" -UserAgent $ua -TimeoutSec 45 -UseBasicParsing
                    if ($cdx.Content.Length -gt 20) {
                        $rows = $cdx.Content | ConvertFrom-Json
                        if ($rows.Count -gt 1) {
                            $last = $rows[-1]
                            $ts = $last[1]; $orig = $last[2]
                            $snap = "https://web.archive.org/web/$ts/$orig"
                            $rec.wayback_url = $snap; $rec.wayback_date = $ts; $rec.method += 'wayback'
                            foreach ($sfx in @('', 'contact', 'contact-us', 'about')) {
                                $u = if ($sfx) { "https://web.archive.org/web/$ts/$($orig.TrimEnd('/'))/$sfx" } else { $snap }
                                try {
                                    $w = Invoke-WebRequest -Uri $u -UserAgent $ua -TimeoutSec 40 -UseBasicParsing
                                    if ($w.StatusCode -eq 200) { $c = Get-Contacts $w.Content; $rec.emails += $c.emails; $rec.phones += $c.phones }
                                } catch {}
                            }
                        }
                    }
                } catch {}
            }
            if ($rec.wayback_url -and $rec.mx_domain) { break }
        }
        if ($rec.wayback_url -or $rec.mx_domain -or $rec.ct_hostnames.Count) { break }
    }
    $rec.emails = @($rec.emails | Select-Object -Unique)
    $rec.phones = @($rec.phones | Select-Object -Unique)
    $rec.method = @($rec.method | Select-Object -Unique)
    if ($rec.emails.Count -or $rec.phones.Count) { $found++; $rec.note = 'contacts recovered from archived site — VERIFY they are current before use' }
    elseif ($rec.mx_domain) { $rec.note = 'domain accepts mail; info@ address is INFERRED, not published — verify before use' }
    elseif ($rec.ct_hostnames.Count) { $rec.note = 'TLS certs exist for this domain, so it is/was in use; no contacts recovered' }
    else { $rec.note = 'no archived site, no MX, no TLS certs — no web footprint of any kind' }
    $results.Add([pscustomobject]$rec)
    $seen[$h.holder] = $true
    if (($i % $SaveEvery) -eq 0) { Save-Out; Write-Host ("  {0}/{1}  recovered-contacts {2}" -f $i, $work.Count, $found) }
}
Save-Out
Write-Host "DONE. attempted $($results.Count) | holders with recovered contacts: $found"
